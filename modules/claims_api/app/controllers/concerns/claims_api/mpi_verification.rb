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
        raise Common::Exceptions::RecordNotFound, 'Veteran in MPI'
      end
    end
  end
end
