# frozen_string_literal: true

require 'chip/service'

module Mobile
  module V0
    class CheckInController < ApplicationController
      def create
        response = chip_service.post_patient_check_in(appointment_ien: params[:appointmentIEN], patient_dfn:,
                                                      station_no: params[:locationId])
        attributes = JSON.parse(response.body)&.dig('data', 'attributes')
        if (error = parse_error(attributes))
          raise(*error)
        else
          render json: Mobile::V0::CheckInSerializer.new(@current_user.id, attributes)
        end
      end

      private

      def patient_dfn
        @current_user.vha_facility_hash.dig(params[:locationId], 0)
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

      def parse_error(attributes)
        @error ||= begin
          error = attributes&.dig('errors', 0)
          message = attributes&.dig('message')

          if error.present?
            case message
            when 'Check-in unsuccessful with appointmentIen: appt-ien, patientDfn: patient-ien, stationNo: station-no'
              [Common::Exceptions::ParameterMissing, 'appointmentIEN and/or locationId']
            end
          end
        end
      end
    end
  end
end
