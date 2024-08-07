# frozen_string_literal: true

module ClaimsApi
  module V2
    module Error
      class ErrorMessage
        def initialize(error)
          @error = error
        end

        def message
          'default - An error has occurred'
        end
      end

      class OriginalBody < ErrorMessage
        def message
          @error.original_body
        end
      end

      class Messages < ErrorMessage
        def message
          @error.messages
        end
      end

      class Errors < ErrorMessage
        def message
          @error.errors
        end
      end

      class DetailedMessage < ErrorMessage
        def message
          @error.detailed_message
        end
      end
    end
  end
end
