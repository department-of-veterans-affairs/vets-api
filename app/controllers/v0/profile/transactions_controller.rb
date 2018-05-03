# frozen_string_literal: true

module V0
  module Profile
    class TransactionsController < ApplicationController

      # before_action { authorize :vet360, :access? }
      
      def status
        transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(@current_user, vet360_service, transaction_params[:transaction_id])
        raise Common::Exceptions::RecordNotFound, transaction unless transaction
        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      private

      def transaction_params
        params.permit :transaction_id
      end

      def vet360_service
        ::Vet360::ContactInformation::Service.new(@current_user) # @TODO this is stinky
      end

    end
  end
end
