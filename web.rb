require 'sinatra'
require 'json'
require 'cosm-rb'
require 'uri'

enable :logging

get '/' do
  "Travis to Cosm"
end

post '/notifications' do
  content_type :json

  data = JSON.parse(URI.unescape(request.body.read).gsub('payload=', ''))

  puts "=========================================================\n"
  puts data.inspect
  puts "=========================================================\n"


  API_KEY = ENV["cosm_api_key"]
  FEED_ID = ENV["cosm_feed_id"]

  repository = data["repository"]["name"]
  status = data["status"]
  status_message = data["status_message"].to_s.downcase

  return unless ["develop", "master"].include?(data["branch"])

  feed = Cosm::Feed.new(:id => FEED_ID)
  overall_status = 'R'

  { repository.to_sym => status }.each_pair do |key,value|
      datastream = Cosm::Datastream.new(:id => key, :feed_id => FEED_ID)
      datastream.datapoints = [Cosm::Datapoint.new(:at => Time.now, :value => value)]
      feed.datastreams = [datastream]
      Cosm::Client.put("/v2/feeds/#{FEED_ID}",
               :headers => {"X-ApiKey" => API_KEY},
               :body => feed.to_json)
  end

  response = Cosm::Client.get("/v2/feeds/#{FEED_ID}", :headers => {"X-ApiKey" => API_KEY})

  if status_message == "pending"
    overall_status = "A"
  elsif response
    current_datastreams = JSON.parse(response.body)["datastreams"].delete_if{ |c| c["id"] == 'rag'}
    overall_status = current_datastreams.all? {|c| c["current_value"] == "0"} ? "G" : "R"
  end

  { :rag => overall_status }.each_pair do |key,value|
      datastream = Cosm::Datastream.new(:id => key, :feed_id => FEED_ID)
      datastream.datapoints = [Cosm::Datapoint.new(:at => Time.now, :value => value)]
      feed.datastreams = [datastream]
      Cosm::Client.put("/v2/feeds/#{FEED_ID}",
               :headers => {"X-ApiKey" => API_KEY},
               :body => feed.to_json)
  end
end
