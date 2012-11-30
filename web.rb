require 'sinatra'
require 'json'

get '/' do
  "Travis to Cosm"
end

post '/notifications' do
	content_type :json
  data = JSON.parse(request.body.read)
end
