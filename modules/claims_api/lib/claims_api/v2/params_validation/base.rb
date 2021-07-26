# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      class Base
        include ActiveModel::Validations

        attr_reader :data

        def initialize(data)
          @data = data || {}
        end

        def read_attribute_for_validation(key)
          data[key]
        end

        protected

        def add_nested_errors_for(_attribute, other_validator)
          errors.merge!(other_validator.errors)
        end
      end
    end
  end
end
