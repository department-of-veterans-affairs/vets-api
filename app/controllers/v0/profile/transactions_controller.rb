# frozen_string_literal: true

module V0
  module Profile
    class TransactionsController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def status
        transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
          @current_user,
          service,
          transaction_params[:transaction_id]
        )

        raise Common::Exceptions::RecordNotFound, transaction unless transaction

        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      def statuses
        transactions = AsyncTransaction::Vet360::Base.refresh_transaction_statuses(@current_user, service)

        render json: transactions, each_serializer: AsyncTransaction::BaseSerializer
      end

      private

      def transaction_params
        params.permit :transaction_id
      end

      def service
        ::Vet360::ContactInformation::Service.new(@current_user)
      end
    end
  end
end
