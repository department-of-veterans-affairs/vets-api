# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        class InvalidFieldValue < StandardError
          def initialize(options = {})
            @title = options[:title] || 'Invalid field value'
            @detail = options[:detail]

            super
          end

          def errors
            [
              {
                title: @title,
                detail: @detail,
                status: status_code.to_s # LH standards want this as a string
              }
            ]
          end

          # When the error is rendered this value is read and needs
          # to be an integer, if it is a string it will be percieved as a 200
          def status_code
            400
          end
        end
      end
    end
  end
end
