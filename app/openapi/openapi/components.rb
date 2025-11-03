# frozen_string_literal: true

module Openapi
  module Components
    ALL = {
      schemas: {
        Errors: Openapi::Components::Errors::ERRORS,
        Error: Openapi::Components::Errors::ERROR,
        FirstMiddleLastName: Openapi::Components::Name::FIRST_MIDDLE_LAST,
        SimpleAddress: Openapi::Components::Address::SIMPLE_ADDRESS
      }
    }.freeze
  end
end
