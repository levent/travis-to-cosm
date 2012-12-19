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

  API_KEY = ENV["cosm_api_key"]
  FEED_ID = ENV["cosm_feed_id"]

  repository = data["repository"]["name"]
  status = data["status"]
  feed = Cosm::Feed.new(:id => FEED_ID)
  overall_status = 'R'

  response = Cosm::Client.get("/v2/feeds/#{FEED_ID}", :headers => {"X-ApiKey" => API_KEY})

  if response
    current_datastreams = JSON.parse(response.body)["datastreams"].delete_if{ |c| c["id"] == 'rag' || c["id"] == repository}
    overall_status = current_datastreams.push({"id" => repository, "current_value" => status}).all? {|c| c["current_value"] == "0"} ? "G" : "R"
  end

  { repository.to_sym => status, :rag => overall_status }.each_pair do |key,value|
      datastream = Cosm::Datastream.new(:id => key, :feed_id => FEED_ID)
      datastream.datapoints = [Cosm::Datapoint.new(:at => Time.now, :value => value)]
      feed.datastreams = [datastream]
      Cosm::Client.put("/v2/feeds/#{FEED_ID}",
               :headers => {"X-ApiKey" => API_KEY},
               :body => feed.to_json)
  end
end
