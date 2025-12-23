# frozen_string_literal: true

module VRE
  module V0
    class Ch31CaseDetailsController < ApplicationController
      service_tag 'vre-application'

      def show
        response = case_details_service.get_details
        render json: VRE::Ch31CaseDetailsSerializer.new(response)
      end

      private

      def case_details_service
        VRE::Ch31CaseDetails::Service.new(@current_user&.icn)
      end
    end
  end
end
