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

  data = JSON.parse(URI.unescape(request.body.read).gub('payload=', ''))

  API_KEY = ENV["cosm_api_key"]
  FEED_ID = ENV["cosm_feed_id"]

  repository = data["repository"]["name"]
  status = data["status"]

  { repository.to_sym => status, :builds => status }.each_pair do |key,value|
      datastream = Cosm::Datastream.new(:id => key, :feed_id => FEED_ID)
      datastream.datapoints = [Cosm::Datapoint.new(:at => Time.now, :value => value)]
      feed = Cosm::Feed.new(:id => FEED_ID)
      feed.datastreams = [datastream]
      Cosm::Client.put("/v2/feeds/#{FEED_ID}",
               :headers => {"X-ApiKey" => API_KEY},
               :body => feed.to_json)
  end
end
