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

  { repository.to_sym => status }.each_pair do |key,value|
      datapoint = Cosm::Datapoint.new(:at => Time.now, :value => value)
      Cosm::Client.post("/v2/feeds/#{FEED_ID}/datastreams/#{key}/datapoints",
        :headers => {"X-ApiKey" => API_KEY},
        :body => {:datapoints => [datapoint]}.to_json)
  end
end
