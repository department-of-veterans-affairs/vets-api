# frozen_string_literal: true

module V0
  module Profile
    class EmailAddressesController < ApplicationController
      before_action { authorize :vet360, :access? }

      def create
        email_address = Vet360::Models::Email.new email_address_params

        if email_address.valid?
          response = service.post_email email_address

          render json: response, serializer: AsyncTransaction::BaseSerializer
        else
          raise Common::Exceptions::ValidationErrors, email_address
        end
      end

      private

      def service
        Vet360::ContactInformation::Service.new @current_user
      end

      def email_address_params
        params.permit(:email_address)
      end
    end
  end
end
