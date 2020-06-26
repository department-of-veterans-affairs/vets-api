# frozen_string_literal: true

module V0
  module Profile
    class PersonsController < ApplicationController
      include Vet360::Transactionable

      after_action :invalidate_mpi_cache

      def initialize_vet360_id
        response    = Vet360::Person::Service.new(@current_user).init_vet360_id
        transaction = AsyncTransaction::Vet360::InitializePersonTransaction.start(@current_user, response)

        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      def status
        check_transaction_status!
      end

      private

      def invalidate_mpi_cache
        mpi_cache = @current_user.mpi
        mpi_cache.mpi_response
        mpi_cache.destroy
      end
    end
  end
end
