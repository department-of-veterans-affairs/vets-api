# frozen_string_literal: true
require 'singleton'
module Rx
  # Configuration class used to setup the environment used by client
  class Configuration
    include Singleton

    attr_reader :host, :app_token, :open_timeout, :read_timeout

    def initialize
      @host = ENV['MHV_HOST']
      @app_token = ENV['MHV_APP_TOKEN']
      @open_timeout = 15
      @read_timeout = 15
    end

    def base_path
      "#{host}/mhv-api/patient/v1/"
    end

    def request_options
      {
        open_timeout: open_timeout,
        timeout: read_timeout
      }
    end
  end
end
