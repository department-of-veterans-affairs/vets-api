# frozen_string_literal: true

module MPI
  module Responses
    class AddPersonResponse
      attr_reader :status, :parsed_codes, :error

      STATUS = [OK = :ok, SERVER_ERROR = :server_error].freeze

      def initialize(status:, parsed_codes: nil, error: nil)
        @status = status
        @parsed_codes = parsed_codes
        @error = error
      end

      def ok?
        status == OK
      end

      def server_error?
        status == SERVER_ERROR
      end
    end
  end
end
