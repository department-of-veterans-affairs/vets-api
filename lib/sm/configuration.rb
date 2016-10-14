# frozen_string_literal: true
require 'singleton'

module SM
  class Configuration
    include Singleton

    attr_reader :host, :app_token, :open_timeout, :read_timeout

    def initialize
      @host = ENV['MHV_SM_HOST']
      @app_token = ENV['MHV_SM_APP_TOKEN']
      @open_timeout = 15
      @read_timeout = 15
    end

    def base_path
      "#{@host}/mhv-sm-api/patient/v1/"
    end
  end
end
