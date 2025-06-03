# frozen_string_literal: true

require 'mobile/v0/exceptions/custom_errors'

module Mobile
  module V0
    class TravelPayClaimsController < ApplicationController
      before_action :authenticate
      after_action :clear_appointments_cache, only: %i[create]

      def create
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

        submitted_claim = smoc_service.submit_mileage_expense(appt_params)

        new_claim_hash = normalize_submission_response({
                                                         'claimId' => submitted_claim['claimId'],
                                                         'status' => submitted_claim['status'],
                                                         'createdOn' => DateTime.now.to_fs(:iso8601),
                                                         'modifiedOn' => DateTime.now.to_fs(:iso8601)
                                                       })

        render json: TravelPayClaimSummarySerializer.new(new_claim_hash),
               status: :created
        # TODO: error handling is now happening in SMOC service now, do we need this?
        # rescue ArgumentError => e
        #   raise Common::Exceptions::BadRequest, detail: e.message
        # rescue Faraday::ClientError, Faraday::ServerError => e
        #   raise Common::Exceptions::InternalServerError, exception: e
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

      def smoc_service
        @smoc_service ||= TravelPay::SmocService.new(auth_manager, @current_user)
      end

      def clear_appointments_cache
        Mobile::V0::Appointment.clear_cache(@current_user)
      end
    end
  end
end
