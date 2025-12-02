# frozen_string_literal: true

module VRE
  module V0
    class Ch31EligibilityStatusesController < ApplicationController
      service_tag 'vre-application'

      def show
        response = eligibility_service.get_details
        render json: VRE::Ch31EligibilitySerializer.new(response)
      end

      private

      def eligibility_service
        VRE::Ch31Eligibility::Service.new(@current_user&.icn)
      end
    end
  end
end
