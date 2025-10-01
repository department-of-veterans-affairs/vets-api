# frozen_string_literal: true

module V0
  module Profile
    class VetVerificationStatusesController < ApplicationController
      service_tag 'profile'
      before_action { authorize :lighthouse, :access_vet_status? }

      def show
        response = service.get_vet_verification_status(@current_user.icn)
        response['data']['id'] = ''

        render json: response
      end

      private

      def service
        @service ||= VeteranVerification::Service.new
      end
    end
  end
end
