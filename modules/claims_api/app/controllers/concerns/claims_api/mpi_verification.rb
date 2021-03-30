# frozen_string_literal: true

module ClaimsApi
  module MPIVerification
    extend ActiveSupport::Concern

    included do
      def verify_mpi
        raise ::Common::Exceptions::ParameterMissing, 'MPI user' unless target_veteran.mpi_record?
      end
    end
  end
end
