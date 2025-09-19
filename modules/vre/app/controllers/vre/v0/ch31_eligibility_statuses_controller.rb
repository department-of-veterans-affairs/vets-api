# frozen_string_literal: true

module VRE
  module V0
    class Ch31EligibilityStatusesController < ApplicationController
      service_tag 'vre-application'

      # VA dot gov test users
      VETS_USER_0 = '1012667122V019349'

      # RES test users
      VETERAN_INELIGIBLE_200 = '1018616478V531227'

      ICN_SUBSTITUTIONS = {
        VETS_USER_0 => VETERAN_INELIGIBLE_200
      }.freeze

      def show
        response = eligibility_service.get_details
        render json: VRE::Ch31EligibilitySerializer.new(response)
      end

      private

      def eligibility_service
        VRE::Ch31Eligibility::Service.new(icn_or_substitute)
      end

      # Necessary in staging to match VA dot gov test user with RES test data. Temporary solution
      # until new test users can be created
      def icn_or_substitute
        incoming_icn = @current_user&.icn
        return incoming_icn unless Flipper.enabled?(:vre_substitute_icn) && !Rails.env.production?

        ICN_SUBSTIUTIONS[incoming_icn] || incoming_icn
      end
    end
  end
end
