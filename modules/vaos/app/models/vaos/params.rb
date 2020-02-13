# frozen_string_literal: true

require 'vaos/exceptions/validation_errors'

module VAOS
  class Params
    def initialize(user, params)
      @user = user
      @params = params.is_a?(Hash) ? params : params.to_h
    end

    def to_h
      result = schema.call(@params)
      raise_validation_error(result) if result.failure?

      result.to_h
    end

    private

    def raise_validation_error(result)
      raise VAOS::Exceptions::ValidationErrors, result
    end

    # @abstract Subclass is expected to implement #schema
    # @!method schema
    #    Schema that defines the validation rules for the params
  end
end
