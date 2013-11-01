require 'sinatra'
require 'json'
require 'cosm-rb'
require 'uri'
require 'logger'

enable :logging

before do
  logger.level = Logger::DEBUG
end

get '/' do
  "Travis to Cosm"
end

post '/notifications' do
  logger = Logger.new
  content_type :json

  data = JSON.parse(URI.unescape(request.body.read).gsub('payload=', ''))

  API_KEY = ENV["cosm_api_key"]
  FEED_ID = ENV["cosm_feed_id"]

  repository = data["repository"]["name"]
  status_message = data["status_message"].to_s.downcase

  # Travis treats pending (running) as 1. We want to differentiate from failed.
  status = status_message == 'pending' ? "2" : data["status"]

  logger.debug "payload\n"
  logger.debug data.inspect
  logger.debug "===================================================="
  logger.debug "branch: #{data["branch"]}\n"

  return unless ["develop", "master"].include?(data["branch"])

  feed = Cosm::Feed.new(:id => FEED_ID)
  overall_status = 'R'

  datastream = Cosm::Datastream.new(:id => repository, :feed_id => FEED_ID)
  datastream.datapoints = [Cosm::Datapoint.new(:at => Time.now, :value => status)]
  feed.datastreams = [datastream]
  Cosm::Client.put("/v2/feeds/#{FEED_ID}",
                   :headers => {"X-ApiKey" => API_KEY},
                   :body => feed.to_json)

  response = Cosm::Client.get("/v2/feeds/#{FEED_ID}", :headers => {"X-ApiKey" => API_KEY})

  if status_message == "pending"
    overall_status = "A"
  elsif response
    current_datastreams = JSON.parse(response.body)["datastreams"].delete_if{ |c| c["id"] == 'rag'}
    if current_datastreams.all? {|c| c["current_value"] == "0"}
      overall_status = "G"
    elsif current_datastreams.any? {|c| c["current_value"] == "2"}
      overall_status = "A"
    else
      overall_status = "R"
    end
  end

  # Update Red, Amber, Green datastream for office traffic light
  datastream = Cosm::Datastream.new(:id => 'rag', :feed_id => FEED_ID)
  datastream.datapoints = [Cosm::Datapoint.new(:at => Time.now, :value => overall_status)]
  feed.datastreams = [datastream]
  Cosm::Client.put("/v2/feeds/#{FEED_ID}",
                   :headers => {"X-ApiKey" => API_KEY},
                   :body => feed.to_json)
end
