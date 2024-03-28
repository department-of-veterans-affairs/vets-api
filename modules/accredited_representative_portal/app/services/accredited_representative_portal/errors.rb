# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Errors
    class StandardError < StandardError
      attr_reader :code

      def initialize(message:, code: SignIn::Constants::ErrorCode::INVALID_REQUEST)
        @code = code
        super(message)
      end
    end

    class RepresentativeRecordNotFoundError < StandardError; end
  end
end
