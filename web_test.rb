require 'web'
require 'test/unit'
require 'rack/test'

set :environment, :test

class MyAppTest < Test::Unit::TestCase
  include Rack::Test::Methods

	def app
		Sinatra::Application
	end

	def test_root_returns_travis_to_cosm
 		get '/'
 		assert last_response.ok?
 		assert_equal 'Travis to Cosm', last_response.body
	end

end
