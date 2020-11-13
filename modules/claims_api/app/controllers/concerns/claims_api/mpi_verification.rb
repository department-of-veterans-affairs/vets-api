# frozen_string_literal: true

module ClaimsApi
  module MPIVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_mpi

      def verify_mpi
        raise "MPI user not found: #{target_veteran.mpi&.response&.error&.inspect}" unless target_veteran.mpi_record?
      rescue => e
        log_message_to_sentry('MPIError in claims',
                              :warning,
                              body: e.message)
        render json: { errors: [{ status: 400, detail: 'Not enough Veteran information, functionality limited.' }] },
               status: :bad_request
      end
    end
  end
end
