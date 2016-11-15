# frozen_string_literal: true
require 'typhoeus'
require 'json'
require 'common/client/errors'

module Facilities
  class MultiClient
    def initialize
      @hydra = Typhoeus::Hydra.new
    end

    def run(requests)
      requests.each { |req| @hydra.queue req }
      @hydra.run
      requests.map do |req|
        if req.response.timed_out?
          Rails.logger.error "GIS request timed out: #{req.url}"
          raise Common::Client::RequestTimeout
        end
        raise Common::Client::Errors::ClientResponse.new(req.response.code, {}) unless
          req.response.success?
        result = JSON.parse(req.response.body)
        if result['error']
          Rails.logger.error "GIS returned error: #{result['error']['code']}, message: #{result['error']['message']}"
          raise Common::Client::Errors::ClientResponse.new(result['error']['code'], {})
        end
        result['features']
      end
    end
  end
end
