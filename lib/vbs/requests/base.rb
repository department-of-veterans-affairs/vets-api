# frozen_string_literal: true

require_relative './invalid_request_error'

module VBS
  module Requests
    class Base
      attr_reader :errors

      def self.schema_validation_options
        {
          errors_as_objects: true,
          version: :draft6
        }
      end

      def http_method
        self.class::HTTP_METHOD
      end

      def path
        self.class::PATH
      end

      def validate!
        validate_request_model!

        @errors = JSON::Validator.fully_validate(self.class.schema, data, self.class.schema_validation_options)

        raise VBS::Requests::InvalidRequestError, errors if @errors.any?

        self
      end

      def valid?
        begin
          validate!
        rescue VBS::Requests::InvalidRequestError
          return false
        end

        true
      end

      private

      def validate_request_model!
        raise "#{self.class.name}::HTTP_METHOD is not defined"  unless self.class.const_defined?(:HTTP_METHOD)
        raise "#{self.class.name}::PATH not defined"            unless self.class.const_defined?(:PATH)
        raise "#{self.class.name}::schema is not defined "      unless defined?(self.class.schema)
      end
    end
  end
end
