# frozen_string_literal: true

require 'va_profile/military_personnel/service'

module Mobile
  module V0
    class MilitaryInformationController < ApplicationController
      before_action { authorize :vet360, :military_access? }
      def get_service_history
        response = service.get_service_history
        json = JSON.parse(response.episodes.to_json, symbolize_names: true)
        parsed_response = military_info_adapter.parse(user.uuid, json)
        log_service_indicator(parsed_response)

        render json: Mobile::V0::MilitaryInformationSerializer.new(parsed_response)
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

      def log_service_indicator(parsed_response)
        if Flipper.enabled?(:mobile_military_indicator_logger, @current_user)
          discharge_codes = parsed_response.service_history.pluck(:honorable_service_indicator)

          data = {
            icn: @current_user.icn,
            discharge_codes:,
            any_y: discharge_codes.any? { |c| c == 'Y' },
            any_z: discharge_codes.any? { |c| c == 'Z' },
            all_z: discharge_codes.all? { |c| c == 'Z' }
          }
          PersonalInformationLog.create(data:, error_class: 'Mobile Military Service Indicator')
        end
      rescue
        nil
      end
    end
  end
end
