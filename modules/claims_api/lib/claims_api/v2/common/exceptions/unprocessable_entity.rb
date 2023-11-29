# frozen_string_literal: true

require_relative 'service_error'

module ClaimsApi
  module V2
    module Common
      module Exceptions
        class UnprocessableEntity < ServiceError
          ERROR_TITLE = 'Unprocessable Entity'

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
