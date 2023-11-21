# frozen_string_literal: true

require 'chip/service'
module Mobile
  module V0
    class CheckInDemographicsController < ApplicationController
      def show
        begin
          response = chip_service.get_demographics(patient_dfn:, station_no: params[:location_id])
        rescue Chip::ServiceException
          raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error'
        end
        parsed_response = Mobile::V0::Adapters::CheckInDemographics.new.parse(response)

        render json: Mobile::V0::CheckInDemographicsSerializer.new(@current_user.uuid, parsed_response)
      end

      def update
        response = chip_service.update_demographics(patient_dfn:, station_no: params[:location_id],
                                                    demographic_confirmations:)
        parsed_response = JSON.parse(response.body, symbolize_names: true)[:data][:attributes]

        render json: Mobile::V0::CheckInUpdateDemographicsSerializer.new(parsed_response)
      end

      private

      def demographic_confirmations
        dc = params[:demographic_confirmations]

        {
          demographicsNeedsUpdate: dc[:contact_needs_update],
          emergencyContactNeedsUpdate: dc[:emergency_contact_needs_update],
          nextOfKinNeedsUpdate: dc[:next_of_kin_needs_update]
        }
      end

      def patient_dfn
        @current_user.vha_facility_hash.dig(params[:location_id], 0)
      end

      def chip_service
        settings = Settings.chip.mobile_app

        chip_creds = {
          tenant_id: settings.tenant_id,
          tenant_name: 'mobile_app',
          username: settings.username,
          password: settings.password
        }.freeze

        ::Chip::Service.new(chip_creds)
      end
    end
  end
end
