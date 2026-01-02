# frozen_string_literal: true

module BEP
  module People
    class Response
      attr_reader :response, :status

      def initialize(response, status: :ok)
        @response = response
        @status = status
      end

      def participant_id
        return if response.blank?

        response[:ptcpnt_id]
      end

      def file_number
        return if response.blank?

        response[:file_nbr]
      end

      def ssn_number
        return if response.blank?

        response[:ssn_nbr]
      end

      def cache?
        status == :ok
      end
    end
  end
end
