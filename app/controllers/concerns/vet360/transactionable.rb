# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'va_profile/contact_information/v2/service'

module Vet360
  module Transactionable
    extend ActiveSupport::Concern

    def check_transaction_status!
      transaction = AsyncTransaction::VAProfile::Base.refresh_transaction_status(
        @current_user,
        service,
        params[:transaction_id]
      )

      raise Common::Exceptions::RecordNotFound, transaction unless transaction

      render json: AsyncTransaction::BaseSerializer.new(transaction).serializable_hash
    end

    private

    def service
      VAProfile::ContactInformation::V2::Service.new @current_user
    end
  end
end
