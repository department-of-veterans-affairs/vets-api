# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'va_profile/contact_information/service'
require 'va_profile/profile_information/service'

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

      render json: transaction, serializer: AsyncTransaction::BaseSerializer
    end

    private

    def service
      if Flipper.enabled?(:va_profile_information_v3_service, @current_user)
        VAProfile::ProfileInformation::Service.new @current_user
      else
        VAProfile::ContactInformation::Service.new @current_user
      end
    end
  end
end
