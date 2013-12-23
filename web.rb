require 'sinatra'
require 'json'
require 'xively-rb'
require 'uri'
require 'logger'
require 'newrelic_rpm'

enable :logging

configure do
  API_KEY = ENV["cosm_api_key"]
  FEED_ID = ENV["cosm_feed_id"]
end

get '/' do
  "Travis to Cosm"
end

get '/dashboard' do
  response = Xively::Client.get("/v2/feeds/#{FEED_ID}", :headers => {"X-ApiKey" => params[:key]})
  current_datastreams = JSON.parse(response.body)["datastreams"]
  rag = (current_datastreams.select { |ds| ds["id"] == 'rag' }).first
  failing = (current_datastreams.select { |ds| ds["current_value"] == '1' })
  passing = (current_datastreams.select { |ds| ds["current_value"] == '0' })
  output = "Overall status: #{rag['current_value']}"
  if failing.any?
    output += " | Failing: "
    output += failing.collect{|f| f['id']}.join(', ')
  end
  output
end

post '/notifications' do
  content_type :json
  logger = Logger.new(STDOUT)
  logger.level = Logger::INFO

  data = JSON.parse(URI.unescape(request.body.read).gsub('payload=', ''))

  repository = data["repository"]["name"]
  branch = data["branch"]
  status_message = data["status_message"].to_s.downcase

  # Travis treats pending (running) as 1. We want to differentiate from failed.
  status = status_message == 'pending' ? "2" : data["status"]
  ignore_branch = !(["develop", "master"].include?(branch))

  logger.info "repo: #{repository}"
  logger.info "branch: #{branch}"
  logger.info "ignore branch: #{ignore_branch}"
  logger.info "build type: #{data['type']}"
  logger.info "status_message: #{status_message}\n"

  return if ignore_branch
  return if data["type"] == "pull_request"

  feed = Xively::Feed.new(:id => FEED_ID)
  overall_status = 'R'

  datastream = Xively::Datastream.new(:id => repository, :feed_id => FEED_ID)
  datastream.datapoints = [Xively::Datapoint.new(:at => Time.now, :value => status)]
  feed.datastreams = [datastream]
  Xively::Client.put("/v2/feeds/#{FEED_ID}",
                   :headers => {"X-ApiKey" => API_KEY},
                   :body => feed.to_json)

  response = Xively::Client.get("/v2/feeds/#{FEED_ID}", :headers => {"X-ApiKey" => API_KEY})

  if status_message == "pending"
    logger.info "overall status: A (pending)"
    overall_status = "A"
  elsif response
    current_datastreams = JSON.parse(response.body)["datastreams"].delete_if{ |c| c["id"] == 'rag'}
    if current_datastreams.all? {|c| c["current_value"] == "0"}
      logger.info "overall status: G (green)"
      overall_status = "G"
    elsif current_datastreams.any? {|c| c["current_value"] == "2"}
      logger.info "overall status: A (pending)"
      overall_status = "A"
    else
      logger.info "overall status: R (red)"
      overall_status = "R"
    end
  end

  # Update Red, Amber, Green datastream for office traffic light
  datastream = Xively::Datastream.new(:id => 'rag', :feed_id => FEED_ID)
  datastream.datapoints = [Xively::Datapoint.new(:at => Time.now, :value => overall_status)]
  feed.datastreams = [datastream]
  Xively::Client.put("/v2/feeds/#{FEED_ID}",
                   :headers => {"X-ApiKey" => API_KEY},
                   :body => feed.to_json)
end
