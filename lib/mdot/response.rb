# frozen_string_literal: true

require 'common/models/base'
require_relative 'eligibility'
require_relative 'supply'
require_relative 'token'
require_relative 'address'

module MDOT
  class Response < Common::Base
    attr_reader :status

    attribute :permanent_address, MDOT::Address
    attribute :temporary_address, MDOT::Address
    attribute :supplies, Array[MDOT::Supply]
    attribute :eligibility, MDOT::Eligibility
    attribute :vet_email, String

    def initialize(args)
      validate_response_against_schema(args[:schema], args[:response])
      @uuid = args[:uuid]
      @response = args[:response]
      @token = @response.response_headers['VAAPIKEY']
      @body = @response.body
      @parsed_body = @body.is_a?(String) ? JSON.parse(@body) : @body
      self.permanent_address = @parsed_body['permanent_address']
      self.temporary_address = @parsed_body['temporary_address']
      self.supplies = @parsed_body['supplies']
      self.vet_email = @parsed_body['vet_email']
      self.eligibility = determine_eligibility
      @status = args[:response][:status]
      update_token
    end

    def determine_eligibility
      eligibility = MDOT::Eligibility.new

      supplies.each do |supply|
        group = supply.product_group.downcase.pluralize.parameterize(separator: '_').to_sym
        eligibility.send("#{group}=", true) if eligibility.attributes.key?(group) && supply.available_for_reorder
      end

      eligibility
    end

    def ok?
      @status == 200
    end

    def accepted?
      @status == 202
    end

    private

    def update_token
      token_params = { REDIS_CONFIG[:mdot][:namespace] => @uuid }
      token = MDOT::Token.new(token_params)
      token.update(token: @token, uuid: @uuid)
    end

    def validate_response_against_schema(schema, response)
      schema_path = Rails.root.join('lib', 'mdot', 'schemas', "#{schema}.json").to_s
      JSON::Validator.validate!(schema_path, response.body, strict: false)
    end
  end
end
