# frozen_string_literal: true

module AppealsApi
  module MPIVeteran
    extend ActiveSupport::Concern

    included do
      # Used to identify the requesting veteran for HLR, NOD, and SC submissions.
      # Calls to target_veteran expect typical request_headers and
      # a request body with identifying veteran attributes.
      #
      # Returns the veteran with MPI attributes, including (of concern to us) their ICN.
      def target_veteran
        veteran ||= Appellant.new(
          type: :veteran,
          auth_headers: request_headers,
          form_data: @json_body&.dig('data', 'attributes', 'veteran')
        )

        mpi_veteran ||= AppealsApi::Veteran.new(
          ssn: veteran.ssn,
          first_name: veteran.first_name,
          last_name: veteran.last_name,
          birth_date: veteran.birth_date.iso8601
        )

        mpi_veteran
      end
    end
  end
end
