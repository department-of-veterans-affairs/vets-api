# frozen_string_literal: true

module ClaimsApi
  module MPIVerification
    extend ActiveSupport::Concern

    included do
      def verify_mpi
        raise 'MPI user not found' unless target_veteran.mpi_record?
      rescue => e
        log_message_to_sentry('MPIError in claims',
                              :warning,
                              body: inspected_error || e.message)

        render json: { errors: [{ status: 400, detail: 'Not enough Veteran information, functionality limited.' }] },
               status: :bad_request
      end

      private

      def inspected_error
        target_veteran.mpi&.response&.error&.inspect
      rescue
        nil
      end
    end
  end
end
