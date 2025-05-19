# frozen_string_literal: true

require 'vets/model'

module GI
  class GIDSResponse
    include Vets::Model

    # @return  [Integer] the response status
    attribute :status, Integer

    # @return  [Hash] the response body
    attribute :body, Hash

    # Builds a response with a ok status and a response's body
    #
    # @param response returned from the rest call
    # @return [GI::GIDSResponse]
    def self.from(response)
      GIDSResponse.new(status: response.status, body: response.body)
    end

    def cache?
      @status == 200
    end

    def initialize(attributes)
      attributes[:body] = nil if attributes[:body].to_s.empty?
      super(attributes)
    end
  end
end
