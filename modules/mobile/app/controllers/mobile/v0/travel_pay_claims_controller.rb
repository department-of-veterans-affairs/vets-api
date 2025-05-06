# frozen_string_literal: true

require 'mobile/v0/exceptions/custom_errors'

module Mobile
  module V0
    class TravelPayClaimsController < ApplicationController
      # Not sure if this is needed - all users must authenticate to use the app, correct?
      # include AppointmentAuthorization
      # before_action :authorize
      after_action :clear_appointments_cache, only: %i[create]

      def create # rubocop:disable Metrics/MethodLength
        begin
          Rails.logger.info(message: 'Mobile-SMOC transaction START')
          appt_id = get_appt_or_raise(params)
          claim_id = get_claim_id(appt_id)

          Rails.logger.info(message: "Mobile-SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
          expense_service.add_expense({ 'claim_id' => claim_id,
                                        'appt_date' => params['appointment_date_time'] })

          Rails.logger.info(message: "Mobile-SMOC transaction: Submit claim #{claim_id.slice(0, 8)}")
          submitted_claim = claims_service.submit_claim(claim_id)

          Rails.logger.info(message: 'Mobile-SMOC transaction END')
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, detail: e.message
        rescue Faraday::ClientError, Faraday::ServerError => e
          raise Common::Exceptions::InternalServerError, exception: e
        end
        claim = Mobile::V0::TravelPayClaimSummary.new({
                                                        id: submitted_claim['claimId'],
                                                        claimNumber: '',
                                                        claimStatus: submitted_claim['status'].underscore.humanize,
                                                        appointmentDateTime: params['appointment_date_time'],
                                                        facilityId: params['facility_station_number'],
                                                        facilityName: '',
                                                        totalCostRequested: 0,
                                                        reimbursementAmount: 0,
                                                        createdOn: submitted_claim['createdOn'],
                                                        modifiedOn: submitted_claim['modifiedOn']
                                                      })
        render json: TravelPayClaimSummarySerializer.new(claim), status: :created
      end

      private

      def validated_params
        smoc_params = {
          appointment_date_time: params['appointment_date_time'],
          facility_station_number: params['facility_station_number'],
          appointment_type: params['appointment_type'] || 'Other',
          is_complete: params['is_complete'] || false
        }

        if params['appointment_name'].present? && !params['appointment_name'].empty?
          smoc_params[:appointment_name] =
            params['appointment_name']
        end

        @validated_params ||= Mobile::V0::Contracts::TravelPaySmoc.new.call(smoc_params)
      end

      def get_appt_or_raise(params)
        appt_not_found_msg = "No appointment found for #{params['appointment_date_time']}"
        Rails.logger.info(message: "SMOC transaction: Get appt by date time: #{params['appointment_date_time']}")
        appt = appts_service.find_or_create_appointment(params)

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
