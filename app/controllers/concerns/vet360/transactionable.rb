# frozen_string_literal: true

module Vet360
  module Transactionable
    extend ActiveSupport::Concern

    def check_transaction_status!
      transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
        @current_user,
        service,
        params[:transaction_id]
      )

      raise Common::Exceptions::RecordNotFound, transaction unless transaction

      render json: transaction, serializer: AsyncTransaction::BaseSerializer
    end

    private

    def service
      Vet360::ContactInformation::Service.new @current_user
    end
  end
end
