# frozen_string_literal: true

module V0
  module Profile
    class TelephonesController < ApplicationController
      before_action { authorize :access? }

      def create
        phone = Vet360::Models::Telephone.new phone_params
        if phone.valid?
          response = service.post_telephone phone # Vet360::ContactInformation::TransactionResponse
          transaction = AsyncTransaction::Vet360::TelephoneTransaction.create(response)
          render json: transaction, serializer: AsyncTransaction::BaseSerializer
        else
          raise Common::Exceptions::ValidationErrors, phone
        end
      end

      # def update
      # end

      private

      def service
        Vet360::ContactInformation::Service.new @current_user
      end

      def phone_params
        params.permit(
          :area_code,
          :country_code,
          :extension,
          :is_international,
          :is_textable,
          :is_text_permitted,
          :is_tty,
          :is_voicemailable,
          :phone_number,
          :phone_type
        )
      end

    end
  end
end
