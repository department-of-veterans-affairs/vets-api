# frozen_string_literal: true

require 'common/models/base'

module MDOT
  class Response < Common::Base
    attr_reader :status

    attribute :permanent_address, MDOT::Address
    attribute :temporary_address, MDOT::Address
    attribute :supplies, Array[MDOT::Supply]

    def initialize(args)
      validate_response_against_schema(args[:schema], args[:response])
      @body = args[:response].body
      @parsed_body = @body.is_a?(String) ? JSON.parse(@body) : @body
      self.permanent_address = @parsed_body['permanent_address']
      self.temporary_address = @parsed_body['temporary_address']
      self.supplies = @parsed_body['supplies']
      @status = args[:response][:status]
    end

    def ok?
      @status == 200
    end

    def accepted?
      @status == 202
    end

    private

    def validate_response_against_schema(schema, response)
      schema_path = Rails.root.join('lib', 'mdot', 'schemas', "#{schema}.json").to_s
      JSON::Validator.validate!(schema_path, response.body, strict: false)
    end
  end
end
