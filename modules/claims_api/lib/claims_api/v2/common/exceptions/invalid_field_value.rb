# frozen_string_literal: true

require_relative 'service_error'

module ClaimsApi
  module V2
    module Common
      module Exceptions
        class InvalidFieldValue < ServiceError
          ERROR_TITLE = 'Invalid Field Value'

          def initialize(options = {})
            @detail = options[:detail]
            @title  = ERROR_TITLE
            @source = options[:source]
            @errors = options[:errors]

            super
          end
        end
      end
    end
  end
end
