# frozen_string_literal: true

require 'common/models/base'

module MDOT
  class Response < Common::Base
    attr_reader :body, :status

    def initialize(args)
      @response = args[:response]
      @status = @response.status
      @schema = validate_schema(args[:schema])
      @body = @response.body if json_format_is_valid?(@response.body, @schema)
    end

    def ok?
      @status == 200
    end

    def accepted?
      @status == 202
    end

    private

    def validate_schema(schema)
      %i[supplies submit].each do |valid_schema|
        return schema.to_s if schema == valid_schema
      end
      nil
    end

    def json_format_is_valid?(body, schema_name)
      schema_path = Rails.root.join('lib', 'mdot', 'schemas', "#{schema_name}.json").to_s
      JSON::Validator.validate!(schema_path, body, strict: false)
    end
  end
end
