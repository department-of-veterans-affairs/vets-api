# frozen_string_literal: true

require 'vet360/person/service'

module V0
  module Profile
    class PersonsController < ApplicationController
      include Vet360::Transactionable

      after_action :invalidate_mvi_cache

      def initialize_vet360_id
        response    = Vet360::Person::Service.new(@current_user).init_vet360_id
        transaction = AsyncTransaction::Vet360::InitializePersonTransaction.start(@current_user, response)

        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      def status
        check_transaction_status!
      end

      private

      def invalidate_mvi_cache
        mvi_cache = @current_user.mpi
        mvi_cache.mvi_response
        mvi_cache.destroy
      end
    end
  end
end
