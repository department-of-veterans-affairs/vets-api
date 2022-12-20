# frozen_string_literal: true

module MPI
  module Responses
    class AddPersonResponse
      attr_reader :status, :parsed_codes, :error

      def initialize(status:, parsed_codes: nil, error: nil)
        @status = status
        @parsed_codes = parsed_codes
        @error = error
      end

      def ok?
        status == :ok
      end

      def server_error?
        status == :server_error
      end
    end
  end
end
