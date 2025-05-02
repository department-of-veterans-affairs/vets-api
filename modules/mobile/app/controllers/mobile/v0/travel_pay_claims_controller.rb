# frozen_string_literal: true

require 'mobile/v0/exceptions/custom_errors'

module Mobile
  module V0
    class TravelPayClaimsController < ApplicationController
      # Ooo.... this checks for ICN and LOA3 - at the base Vets API level, not even Mobile level
      # Unfortunately, it also checks for facilities, which we might not want to do??
      include AppointmentAuthorization

      # This is used for ApptsController, maybe helpful if we do want to check for facilities before allowing TP
      # before_action :authorize_with_facilities

      # This is all we check in TP
      before_action :authorize

      # This might solve the cache issue with the appointments!!
      after_action :clear_appointments_cache, only: %i[create]

      def create
        begin
          Rails.logger.info(message: 'Mobile-SMOC transaction START')

          appt_id = get_appt_or_raise
          claim_id = get_claim_id(appt_id)

          Rails.logger.info(message: "Mobile-SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
          expense_service.add_expense({ 'claim_id' => claim_id,
                                        'appt_date' => validated_params[:appointment_date_time] })

          Rails.logger.info(message: "Mobile-SMOC transaction: Submit claim #{claim_id.slice(0, 8)}")
          submitted_claim = claims_service.submit_claim(claim_id)

          Rails.logger.info(message: 'Mobile-SMOC transaction END')
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, detail: e.message
        rescue Faraday::ClientError, Faraday::ServerError => e
          raise Common::Exceptions::InternalServerError, exception: e
        end

        render json: TravelPayClaimSummarySerializer.new({
                                                           id: submitted_claim['claimId'],
                                                           claimNumber: '',
                                                           claimStatus: submitted_claim['status'],
                                                           appointmentDateTime: validated_params[:appointment_date_time],
                                                           facilityId: validated_params[:facility_station_number],
                                                           facilityName: '',
                                                           createdOn: submitted_claim[:createdOn],
                                                           modifiedOn: submitted_claim[:modifiedOn]
                                                         })
      end

      private

      def validated_params
        @validated_params ||= begin
          appointment_date_time = params[:appointment_date_time] # probably like parse date to check it's valid
          facility_station_number = params[:facility_station_number]
          appointment_type = params[:appointment_type] || 'Other'
          is_complete = params[:is_complete] || false
          # This is optional but will fail if passed an empty string
          appointment_name = params[:appointment_name] || nil

          Mobile::V0::Contracts::TravelPaySmoc.new.call(
            appointment_date_time,
            facility_station_number,
            appointment_type,
            is_complete,
            appointment_name
          )
        end
      end

      def get_appt_or_raise
        appt_not_found_msg = "No appointment found for #{validated_params[:appointment_date_time]}"
        Rails.logger.info(message: "SMOC transaction: Get appt by date time: #{validated_params[:appointment_date_time]}")
        appt = appts_service.find_or_create_appointment(validated_params)

        if appt[:data].nil?
          Rails.logger.error(message: appt_not_found_msg)
          raise Common::Exceptions::ResourceNotFound, detail: appt_not_found_msg
        end

        appt[:data]['id']
      end

      def get_claim_id(appt_id)
        Rails.logger.info(message: 'SMOC transaction: Create claim')
        claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

        claim['claimId']
      end

      def auth_manager
        # TODO: find the mobile client number
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.mobile_client_number, @current_user)
      end

      def claims_service
        @claims_service ||= TravelPay::ClaimsService.new(auth_manager, @current_user)
      end

      def appts_service
        @appts_service ||= TravelPay::AppointmentsService.new(auth_manager)
      end

      def expense_service
        @expense_service ||= TravelPay::ExpensesService.new(auth_manager)
      end

      def clear_appointments_cache
        Mobile::V0::Appointment.clear_cache(@current_user)
      end
    end
  end
end
