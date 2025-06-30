# frozen_string_literal: true

require 'docx'

module TravelPay
  module V0
    class ClaimsController < ApplicationController
      after_action :scrub_logs, only: [:show]

      def index
        claims = claims_service.get_claims(params)
        render json: claims, status: :ok
      rescue Faraday::ResourceNotFound => e
        handle_resource_not_found_error(e.message, e.response[:request][:headers]['X-Correlation-ID'])
      rescue Faraday::Error => e
        TravelPay::ServiceError.raise_mapped_error(e)
      end

      def show
        unless Flipper.enabled?(:travel_pay_view_claim_details, @current_user)
          message = 'Travel Pay Claim Details unavailable per feature toggle'
          raise Common::Exceptions::ServiceUnavailable, message:
        end

        begin
          claim = fetch_claim_with_decision_reason(params[:id])
        rescue Faraday::ResourceNotFound => e
          handle_resource_not_found_error(e.message, e.response[:request][:headers]['X-Correlation-ID'])
          return
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, message: e.message
        end

        if claim.nil?
          handle_resource_not_found_error("Claim not found. ID provided: #{params[:id]}",
                                          e.response[:request][:headers]['X-Correlation-ID'])
          return
        end

        render json: claim, status: :ok
      end

      def create
        unless Flipper.enabled?(:travel_pay_submit_mileage_expense, @current_user)
          message = 'Travel Pay mileage expense submission unavailable per feature toggle'
          Rails.logger.error(message:)
          raise Common::Exceptions::ServiceUnavailable, message:
        end
        begin
          Rails.logger.info(message: 'SMOC transaction START')

          appt_id = get_appt_or_raise(params)
          claim_id = get_claim_id(appt_id)

          Rails.logger.info(message: "SMOC transaction: Add expense to claim #{claim_id.slice(0, 8)}")
          expense_service.add_expense({ 'claim_id' => claim_id, 'appt_date' => params['appointment_date_time'] })

          Rails.logger.info(message: "SMOC transaction: Submit claim #{claim_id.slice(0, 8)}")
          submitted_claim = claims_service.submit_claim(claim_id)

          Rails.logger.info(message: 'SMOC transaction END')
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, detail: e.message
        rescue Faraday::ClientError, Faraday::ServerError => e
          raise Common::Exceptions::InternalServerError, exception: e
        end

        render json: submitted_claim, status: :created
      end

      private

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
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

      def scrub_logs
        logger.filter = lambda do |log|
          if log.name =~ /TravelPay/
            # Safely scrub :params
            log.payload[:params]['id'] = 'SCRUBBED_CLAIM_ID' if log.payload[:params].is_a?(Hash)

            # Safely scrub :path
            if log.payload[:path].is_a?(String)
              log.payload[:path] = log.payload[:path].gsub(%r{(.+claims/)(.+)}, '\1SCRUBBED_CLAIM_ID')
            end

            # Safely scrub :referer if present
            if log.named_tags&.key?(:referer) && log.named_tags[:referer].is_a?(String)
              log.named_tags[:referer] = log.named_tags[:referer].gsub(%r{(.+claims/)(.+)(.+)}, '\1SCRUBBED_CLAIM_ID')
            end
          end

          true
        end
      end

      def get_appt_or_raise(params = {})
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

      def handle_resource_not_found_error(message, cid)
        Rails.logger.error("Resource not found: #{message}")
        render(
          json: {
            error: 'Not found',
            correlation_id: cid
          },
          status: :not_found
        )
      end

      def fetch_claim_with_decision_reason(cid)
        claim = claims_service.get_claim_details(cid)

        if %w[Denied PartialPayment].include?(claim['claimStatus'])
          decision_document = find_decision_letter_document(claim)
          claim['all_denial_reasons'] = get_decision_reason(cid, decision_document['id']) if decision_document
        end

        if claim.nil?
          handle_resource_not_found_error(
            "Claim not found. ID provided: #{cid}",
            nil # correlation_id not available when claim is nil
          )
        else
          claim
        end
      rescue Faraday::ResourceNotFound => e
        handle_resource_not_found_error(e.message, error.response[:request][:headers]['X-Correlation-ID'])
      rescue Faraday::Error => e
        TravelPay::ServiceError.raise_mapped_error(e)
      rescue ArgumentError => e
        raise Common::Exceptions::BadRequest, message: e.message
      end

      def get_decision_reason(cid, did)
        document_data = documents_service.download_document(cid, did)
        doc = Docx::Document.open(document_data[:body])

        doc.paragraphs.each_with_index do |paragraph, index|
          next unless paragraph_is_bold?(paragraph)

          result = check_paragraph_for_decision_reason(paragraph, doc.paragraphs[index + 1])
          return result if result
        end

        Rails.logger.error('Target heading not found')
        nil
      end

      def check_paragraph_for_decision_reason(paragraph, next_paragraph)
        return nil unless next_paragraph

        paragraph_text = paragraph.to_s

        if should_check_cfr_for_denial?(paragraph_text, next_paragraph)
          log_and_return_decision_reason('rejection', next_paragraph)
        elsif paragraph_text.include?('Partial payment reason')
          log_and_return_decision_reason('partial payment', next_paragraph)
        end
      end

      def should_check_cfr_for_denial?(paragraph_text, next_paragraph)
        paragraph_text.include?('Denial reason') &&
          next_paragraph.to_s.match(/Authority \d+ CFR \d+\.\d+/)
      end

      def log_and_return_decision_reason(reason_type, paragraph)
        Rails.logger.info("Decision #{reason_type} reason found: \"#{paragraph}\"")
        paragraph.to_s
      end

      def paragraph_is_bold?(paragraph)
        paragraph.runs.any?(&:bold?)
      end

      def find_decision_letter_document(claim)
        return nil unless claim&.dig('documents')

        claim['documents'].find do |document|
          filename = document['filename'] || ''
          filename.match?(/Decision Letter|Rejection Letter/i)
        end
      end
    end
  end
end
