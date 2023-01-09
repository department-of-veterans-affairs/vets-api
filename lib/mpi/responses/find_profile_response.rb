# frozen_string_literal: true

module MPI
  module Responses
    class FindProfileResponse
      attr_reader :status, :profile, :error

      STATUS = [OK = :ok, NOT_FOUND = :not_found, SERVER_ERROR = :server_error].freeze

      def initialize(status:, profile: nil, error: nil)
        @status = status
        @profile = profile
        @error = error
      end

      def cache?
        ok? || not_found?
      end

      def ok?
        @status == OK
      end

      def not_found?
        @status == NOT_FOUND
      end

      def server_error?
        @status == SERVER_ERROR
      end
    end
  end
end
