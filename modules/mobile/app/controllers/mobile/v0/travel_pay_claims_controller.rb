# frozen_string_literal: true

require 'mobile/v0/exceptions/custom_errors'

module Mobile
  module V0
    class TravelPayClaimsController < ApplicationController
      before_action :authenticate
      after_action :clear_appointments_cache, only: %i[create]

      def create
        Rails.logger.info(message: '[VAHB] SMOC transaction START')

        claim_id = get_claim_id
        Rails.logger.info(message: "[VAHB] SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
        expense_service.add_expense({ 'claim_id' => claim_id,
                                      'appt_date' => validated_params[:appointment_date_time] })
        Rails.logger.info(message: "[VAHB] SMOC transaction: Submit claim #{claim_id.slice(0, 8)}")
        submitted_claim = claims_service.submit_claim(claim_id)

        Rails.logger.info(message: '[VAHB] SMOC transaction END')

        new_claim_hash = normalize_submission_response({
          'claimId' => submitted_claim['claimId'],
          'status' => 'ClaimSubmitted',
          'createdOn' => DateTime.now.to_fs(:iso8601),
          'modifiedOn' => DateTime.now.to_fs(:iso8601)
          })

        render json: TravelPayClaimSummarySerializer.new(new_claim_hash),
               status: :created
      rescue ArgumentError => e
        raise Common::Exceptions::BadRequest, detail: e.message
      rescue Faraday::ClientError, Faraday::ServerError => e
        raise Common::Exceptions::InternalServerError, exception: e
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

      def get_appt_or_raise
        appt_params = {
          'appointment_date_time' => validated_params[:appointment_date_time],
          'facility_station_number' => validated_params[:facility_station_number],
          'appointment_type' => validated_params[:appointment_type],
          'is_complete' => validated_params[:is_complete]
        }
        if validated_params[:appointment_name].present?
          appt_params['appointment_name'] =
            validated_params[:appointment_name]
        end
        appt_not_found_msg = "[VAHB] No appointment found for #{appt_params['appointment_date_time']}"
        Rails.logger.info(message:
                          "[VAHB] SMOC transaction: Get appt by date time: #{appt_params['appointment_date_time']}")
        appt = appts_service.find_or_create_appointment(appt_params)

        if appt[:data].nil?
          Rails.logger.error(message: appt_not_found_msg)
          raise Common::Exceptions::ResourceNotFound, detail: appt_not_found_msg
        end

        appt[:data]['id']
      end

      def get_claim_id
        appt_id = get_appt_or_raise
        Rails.logger.info(message: '[VAHB] SMOC transaction: Create claim')
        claim = claims_service.create_new_claim({ 'btsss_appt_id' => appt_id })

        claim['claimId']
      end

      def normalize_submission_response(submitted_claim)
        Mobile::V0::TravelPayClaimSummary.new({
                                                id: submitted_claim['claimId'],
                                                claimNumber: '',
                                                claimStatus: submitted_claim['status'].underscore.humanize,
                                                appointmentDateTime: validated_params[:appointment_date_time],
                                                facilityId: validated_params[:facility_station_number],
                                                facilityName: '',
                                                totalCostRequested: 0,
                                                reimbursementAmount: 0,
                                                createdOn: submitted_claim['createdOn'],
                                                modifiedOn: submitted_claim['modifiedOn']
                                              })
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
