require 'sinatra'
require 'json'
require 'cosm-rb'

get '/' do
  "Travis to Cosm"
end

post '/notifications' do
  data = JSON.parse(request.body.read)

  config = YAML.load_file('config/cosm.yml')
  API_KEY = config["api_key"]
  FEED_ID = config["feed_id"]

  repository = data["repository"]["name"]
  status = data["status_message"] == "Passed" ? 1 : 0

  { repository.to_sym => status }.each_pair do |key,value|
      datapoint = Cosm::Datapoint.new(:at => Time.now, :value => value)
      Cosm::Client.post("/v2/feeds/#{FEED_ID}/datastreams/#{key}/datapoints",
        :headers => {"X-ApiKey" => API_KEY},
        :body => {:datapoints => [datapoint]}.to_json)
  end


end
