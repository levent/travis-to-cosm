require 'rubygems'
require 'bundler'
require 'csv'

Bundler.require

require './web.rb'
run Sinatra::Application
