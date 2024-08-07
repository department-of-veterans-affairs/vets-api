# frozen_string_literal: true

require 'error_message'

module ClaimsApi
  module V2
    module Error
      class ErrorBase
        MESSAGES = [ClaimsApi::V2::Error::OriginalBody.new(error),
                    ClaimsApi::V2::Error::Messages.new(error),
                    ClaimsApi::V2::Error::Errors.new(error),
                    ClaimsApi::V2::Error::DetailedMessage.new(error)].freeze

        def initialize(error)
          @error = error
        end

        def get_error_message
          MESSAGES.each(&:message)
        end
      end
    end
  end
end
