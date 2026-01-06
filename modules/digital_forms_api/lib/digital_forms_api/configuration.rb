# frozen_string_literal: true

module DigitalFormsApi
  class Configuration
    attr_accessor :base_url, :api_key, :timeout

    def initialize
      @base_url = 'https://api.digitalforms.example.com'
      @api_key = nil
      @timeout = 60 # seconds
    end
  end
end
