# frozen_string_literal: true

module ClaimsApi
  module MPIVerification
    extend ActiveSupport::Concern

    included do
      before_action :verify_mpi

      def verify_mpi
        raise 'MPI user not found' unless target_veteran.mpi_record?
      rescue => e
        log_message_to_sentry('MPIError in claims',
                              :warning,
                              body: target_veteran.mpi&.response&.error&.inspect || e.message)
        render json: { errors: [{ status: 404, detail: 'Veteran not found, some functionality may be limited.' }] },
               status: :not_found
      end
    end
  end
end
