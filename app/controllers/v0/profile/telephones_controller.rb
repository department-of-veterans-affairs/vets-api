# frozen_string_literal: true

module V0
  module Profile
    class TelephonesController < ApplicationController
      before_action { authorize :vet360, :access? }

      def create
        telephone = Vet360::Models::Telephone.new(telephone_params).set_defaults(@current_user)

        if telephone.valid?
          response    = service.post_telephone telephone
          transaction = AsyncTransaction::Vet360::TelephoneTransaction.start(@current_user, response)

          render json: transaction, serializer: AsyncTransaction::BaseSerializer
        else
          raise Common::Exceptions::ValidationErrors, telephone
        end
      end

      def update
        telephone = Vet360::Models::Telephone.new(telephone_params).set_defaults(@current_user)

        if telephone.valid?
          response    = service.put_telephone telephone
          transaction = AsyncTransaction::Vet360::TelephoneTransaction.start @current_user, response

          render json: transaction, serializer: AsyncTransaction::BaseSerializer
        else
          raise Common::Exceptions::ValidationErrors, telephone
        end
      end

      private

      def service
        Vet360::ContactInformation::Service.new @current_user
      end

      def telephone_params
        params.permit(
          :area_code,
          :country_code,
          :extension,
          :effective_end_date,
          :effective_start_date,
          :id,
          :is_international,
          :is_textable,
          :is_text_permitted,
          :is_tty,
          :is_voicemailable,
          :phone_number,
          :phone_type,
          :source_date,
          :transaction_id,
          :vet360_id
        )
      end
    end
  end
end
