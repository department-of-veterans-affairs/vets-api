# frozen_string_literal: true

require 'vets/model'

module Vets
  class Response
    include Vets::Model

    STATUS_TEXTS = {
      200 => 'OK',
      403 => 'NOT_AUTHORIZED',
      404 => 'NOT_FOUND'
    }.freeze

    attribute :status_code, Integer
    attribute :body, Hash

    def self.build_from_response(response, schema_name: nil)
      status_code = response.try(:status) || response[:status]
      body = response.try(:body) || response[:body]
      Vets::Response.new(status_code:, body:, schema_name:)
    end

    #
    # @!attribute body
    #   @return [Hash] Validated response body.
    # @!attribute status
    #   @return [Integer] The HTTP status code.
    # @!attribute schema_name
    #   @return [String] File name without extention
    #   @see validate_body_schema
    #
    def initialize(status_code:, body:, schema_name: nil)
      super(status_code: status_code.to_i, body: parse_json(body))

      validate_body_schema(body, schema_name) if schema_name
    end

    def ok?
      status_code == 200
    end

    def accepted?
      status_code == 202
    end

    def cache?
      ok?
    end

    def metadata
      { status: STATUS_TEXTS.fetch(status_code, 'SERVER_ERROR') }
    end

    private

    def validate_body_schema(body, schema_name)
      schema_path = Rails.root.join('lib', 'apps', 'schemas', "#{schema_name}.json").to_s
      JSON::Validator.validate!(schema_path, body, strict: false)
    end

    def parse_json(body)
      return body if body.is_a?(Hash) || body.nil?

      JSON.parse(body)
    end
  end
end
