# frozen_string_literal: true

module V0
  module Profile
    class VetVerificationStatusesController < ApplicationController
      service_tag 'profile'
      before_action { authorize :lighthouse, :access? }

      def show
        access_token = settings.access_token
        response = service.get_vet_verification_status(@current_user.icn, access_token.client_id, access_token.rsa_key)
        response['data']['id'] = ''

        render json: response
      end

      private

      def service
        @service ||= VeteranVerification::Service.new
      end

      def settings
        Settings.lighthouse.veteran_verification['status']
      end
    end
  end
end
