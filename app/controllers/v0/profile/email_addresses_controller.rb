# frozen_string_literal: true

module V0
  module Profile
    class EmailAddressesController < ApplicationController
      before_action { authorize :vet360, :access? }

      def create
        email_address = Vet360::Models::Email.new(email_address_params).set_defaults(@current_user)

        if email_address.valid?
          response    = service.post_email email_address
          transaction = AsyncTransaction::Vet360::EmailTransaction.start(@current_user, response)

          render json: transaction, serializer: AsyncTransaction::BaseSerializer
        else
          raise Common::Exceptions::ValidationErrors, email_address
        end
      end

      def update
        email_address = Vet360::Models::Email.new(email_address_params).set_defaults(@current_user)

        if email_address.valid?
          response    = service.put_email email_address
          transaction = AsyncTransaction::Vet360::EmailTransaction.start @current_user, response

          render json: transaction, serializer: AsyncTransaction::BaseSerializer
        else
          raise Common::Exceptions::ValidationErrors, email_address
        end
      end

      private

      def service
        Vet360::ContactInformation::Service.new @current_user
      end

      def email_address_params
        params.permit(
          :email_address,
          :effective_end_date,
          :effective_start_date,
          :id,
          :source_date,
          :transaction_id,
          :vet360_id
        )
      end
    end
  end
end
