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

post '/notifications' do
  content_type :json
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG

  data = JSON.parse(URI.unescape(request.body.read).gsub('payload=', ''))

  repository = data["repository"]["name"]
  branch = data["branch"]
  status_message = data["status_message"].to_s.downcase

  # Travis treats pending (running) as 1. We want to differentiate from failed.
  status = status_message == 'pending' ? "2" : data["status"]

  logger.debug "payload\n"
  logger.debug data.inspect
  logger.debug "===================================================="
  logger.debug "repo: #{repository}"
  logger.debug "branch: #{branch}"
  logger.debug "status_message: #{status_message}\n"

  return unless ["develop", "master"].include?(branch)
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
    logger.debug "overall status: A (pending)"
    overall_status = "A"
  elsif response
    current_datastreams = JSON.parse(response.body)["datastreams"].delete_if{ |c| c["id"] == 'rag'}
    if current_datastreams.all? {|c| c["current_value"] == "0"}
      logger.debug "overall status: G (green)"
      overall_status = "G"
    elsif current_datastreams.any? {|c| c["current_value"] == "2"}
      logger.debug "overall status: A (pending)"
      overall_status = "A"
    else
      logger.debug "overall status: R (red)"
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
