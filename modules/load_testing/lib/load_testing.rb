require 'load_testing/version'
require 'load_testing/engine'
require 'load_testing/middleware/access_control'

module LoadTesting
  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end

  class Configuration
    attr_accessor :allowed_teams, :max_concurrent_users, :token_lifetime, :api_base_url

    def initialize
      @allowed_teams = ['identity']
      @max_concurrent_users = 1000
      @token_lifetime = 30.minutes
      @api_base_url = ENV.fetch('LOAD_TEST_API_URL', 'http://localhost:3000')
    end
  end
end 