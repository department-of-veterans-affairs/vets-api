# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'va_profile/contact_information/service'
require 'va_profile/v2/contact_information/service'

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
      if Flipper.enabled?(:remove_pciu, @current_user)
        VAProfile::V2::ContactInformation::Service.new @current_user
      else
        VAProfile::ContactInformation::Service.new @current_user
      end
    end
  end
end
