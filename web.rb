require 'sinatra'
require 'json'

get '/' do
  "Travis to Cosm"
end

post '/notifications' do
  data = JSON.parse(params)
  p params
end
