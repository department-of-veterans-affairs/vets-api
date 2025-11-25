# frozen_string_literal: true

module Mobile
  module V0
    class VetVerificationStatusesController < ApplicationController
      def show
        response = service.get_vet_verification_status(@current_user.icn)
        response['data']['id'] = ''

        render json: response
      end

      private

      def service
        @service ||= Mobile::V0::VeteranVerification::Service.new
      end
    end
  end
end
