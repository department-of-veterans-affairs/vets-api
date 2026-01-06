# frozen_string_literal: true

require 'mobile/v0/exceptions/custom_errors'

module Mobile
  module V0
    class TravelPayClaimsController < ApplicationController
      before_action :authenticate

      def index
        claims_response = claims_service.get_claims_by_date_range(
          'start_date' => index_params[:start_date].to_s,
          'end_date' => index_params[:end_date].to_s,
          'page_number' => index_params[:page_number]
        )
        claims = claims_response[:data].map { |claim_data| normalize_claim_summary(claim_data) }
        status = claims_response[:metadata]['status'] == 206 ? :partial_content : :ok

        render json: Mobile::V0::TravelPayClaimSummarySerializer.new(claims, { meta: claims_response[:metadata] }),
               status:
      end

      # rubocop:disable Metrics/MethodLength
      def show
        claim = claims_service.get_claim_details(params[:id])

        raise Common::Exceptions::ResourceNotFound, detail: "Claim not found. ID provided: #{params[:id]}" if claim.nil?

        detailed_claim = Mobile::V0::TravelPayClaimDetails.new(
          id: claim['claimId'] || claim['id'],
          claimNumber: claim['claimNumber'],
          claimName: claim['claimName'],
          claimantFirstName: claim['claimantFirstName'],
          claimantMiddleName: claim['claimantMiddleName'],
          claimantLastName: claim['claimantLastName'],
          claimStatus: claim['claimStatus'],
          appointmentDate: claim['appointmentDate'] || claim['appointmentDateTime'],
          facilityName: claim['facilityName'],
          totalCostRequested: claim['totalCostRequested'],
          reimbursementAmount: claim['reimbursementAmount'],
          rejectionReason: claim['rejectionReason'],
          decisionLetterReason: claim['decision_letter_reason'],
          appointment: claim['appointment'],
          expenses: claim['expenses'],
          documents: claim['documents'],
          createdOn: claim['createdOn'],
          modifiedOn: claim['modifiedOn']
        )

        render json: Mobile::V0::TravelPayClaimDetailsSerializer.new(detailed_claim), status: :ok
      rescue ArgumentError => e
        raise Common::Exceptions::BadRequest, detail: e.message
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

        new_claim_hash = normalize_claim_summary({
                                                   'id' => submitted_claim['claimId'],
                                                   'claimNumber' => '',
                                                   'claimStatus' => submitted_claim['status'].underscore.humanize,
                                                   'appointmentDateTime' => validated_params[:appointment_date_time],
                                                   'facilityId' => validated_params[:facility_station_number],
                                                   'facilityName' => validated_params[:facility_name],
                                                   'totalCostRequested' => 0,
                                                   'reimbursementAmount' => 0,
                                                   'createdOn' => DateTime.now.to_fs(:iso8601),
                                                   'modifiedOn' => DateTime.now.to_fs(:iso8601)
                                                 })

        render json: TravelPayClaimSummarySerializer.new(new_claim_hash),
               status: :created
      end

      def download_document
        document_id = CGI.unescape(params[:document_id])

        documents_service = TravelPay::DocumentsService.new(auth_manager)
        document_data = documents_service.download_document(params[:claim_id], document_id)

        send_data(
          document_data[:body],
          type: document_data[:type],
          disposition: document_data[:disposition]
        )
      rescue ArgumentError
        Rails.logger.error(
          "Invalid travel pay document request: claim_id=#{params[:claim_id]&.first(8)}, " \
          "document_id=#{params[:document_id]&.first(8)}"
        )
        head :bad_request
      rescue Faraday::ResourceNotFound
        Rails.logger.error(
          "Travel pay document not found: claim_id=#{params[:claim_id]&.first(8)}, " \
          "document_id=#{params[:document_id]&.first(8)}"
        )
        head :not_found
      rescue => e
        Rails.logger.error("Error downloading travel pay document: #{e.class}, #{e.message}")
        head :internal_server_error
      end
      # rubocop:enable Metrics/MethodLength

      private

      def normalize_claim_summary(claim)
        Mobile::V0::TravelPayClaimSummary.new(
          id: claim['id'] || claim['claimId'],
          claimNumber: claim['claimNumber'],
          claimStatus: claim['claimStatus'],
          appointmentDateTime: claim['appointmentDateTime'] || claim['appointmentDate'],
          facilityId: claim['facilityId'] || claim.dig('appointment', 'facilityId'),
          facilityName: claim['facilityName'],
          totalCostRequested: claim['totalCostRequested'],
          reimbursementAmount: claim['reimbursementAmount'],
          createdOn: claim['createdOn'],
          modifiedOn: claim['modifiedOn']
        )
      end

      def index_params
        get_all_params = {
          start_date: params['start_date'],
          end_date: params['end_date']
        }

        get_all_params[:page_number] = params['page_number'] if params['page_number'].present?

        @index_params ||= Mobile::V0::Contracts::TravelPayClaims.new.call(get_all_params)
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

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.mobile_client_number, @current_user)
      end

      def smoc_service
        @smoc_service ||= TravelPay::SmocService.new(auth_manager, @current_user, 'VAHB')
      end

      def claims_service
        @claims_service ||= TravelPay::ClaimsService.new(auth_manager, @current_user)
      end
    end
  end
end
