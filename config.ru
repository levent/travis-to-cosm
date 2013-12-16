require 'rubygems'
require 'bundler'
require 'csv'

Bundler.require

$stdout.sync = true

require './web.rb'
run Sinatra::Application
