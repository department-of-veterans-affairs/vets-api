# frozen_string_literal: true

module V0
  module Profile
    class AlternatePhonesController < ApplicationController
      before_action { authorize :evss, :access? }

      def show
        response = service.get_alternate_phone

        render json: response, serializer: PhoneNumberSerializer
      end

      private

      def service
        EVSS::PCIU::Service.new @current_user
      end
    end
  end
end
