# frozen_string_literal: true

require 'mobile/v0/exceptions/custom_errors'
require 'securerandom'

module Mobile
  module V0
    class TravelPayClaimsController < ApplicationController
      before_action :authenticate
      before_action :validate_index_params, only: [:index]
      after_action :clear_appointments_cache, only: %i[create]

      def index
        claims_response = fetch_claims_from_service
        claims = transform_claims_data(claims_response[:data])
        status = claims_response[:metadata]['status'] == 206 ? :partial_content : :ok

        render json: Mobile::V0::TravelPayClaimSummarySerializer.new(claims, { meta: claims_response[:metadata] }),
               status:
      end

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
      end

      private

      def fetch_claims_from_service
        TravelPay::ClaimsService.new(auth_manager, @current_user).get_claims_by_date_range(
          'start_date' => @index_params[:start_date].to_s,
          'end_date' => @index_params[:end_date].to_s,
          'page_number' => @index_params[:page_number]
        )
      end

      def transform_claims_data(claims_data)
        claims_data.map do |claim_data|
          Mobile::V0::TravelPayClaimSummary.new(
            id: claim_data['id'],
            claimNumber: claim_data['claimNumber'],
            claimStatus: claim_data['claimStatus'],
            appointmentDateTime: claim_data['appointmentDateTime'],
            facilityId: claim_data['facilityId'],
            facilityName: claim_data['facilityName'],
            totalCostRequested: claim_data['totalCostRequested'],
            reimbursementAmount: claim_data['reimbursementAmount'],
            createdOn: claim_data['createdOn'],
            modifiedOn: claim_data['modifiedOn']
          )
        end
      end

      def validate_index_params
        contract = Mobile::V0::Contracts::TravelPayClaims.new
        result = contract.call(params.to_unsafe_h)
        raise Common::Exceptions::ValidationErrors, result unless result.success?

        @index_params = result.to_h
      end

      def validated_params
        smoc_params = {
          appointment_date_time: params['appointment_date_time'],
          facility_station_number: params['facility_station_number'],
          facility_name: params['facility_name'],
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
                                                facilityName: validated_params[:facility_name],
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
        @smoc_service ||= TravelPay::SmocService.new(auth_manager, @current_user, 'VAHB')
      end

      def clear_appointments_cache
        Mobile::V0::Appointment.clear_cache(@current_user)
      end
    end
  end
end
