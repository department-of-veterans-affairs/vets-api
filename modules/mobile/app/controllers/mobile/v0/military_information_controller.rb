# frozen_string_literal: true

require 'va_profile/military_personnel/service'

module Mobile
  module V0
    class MilitaryInformationController < ApplicationController
      before_action { authorize :vet360, :military_access? }
      def get_service_history
        response = service.get_service_history
        json = JSON.parse(response.episodes.to_json, symbolize_names: true)

        render json: Mobile::V0::MilitaryInformationSerializer.new(military_info_adapter.parse(user.uuid, json))
      end

      private

      def user
        @current_user
      end

      def military_info_adapter
        Mobile::V0::Adapters::MilitaryInformation.new
      end

      def service
        VAProfile::MilitaryPersonnel::Service.new(user)
      end
    end
  end
end
