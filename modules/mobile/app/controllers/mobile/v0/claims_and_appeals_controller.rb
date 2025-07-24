# frozen_string_literal: true

require 'sentry_logging'
require 'prawn'
require 'fileutils'
require 'mini_magick'
require 'lighthouse/benefits_documents/service'

module Mobile
  module V0
    class ClaimsAndAppealsController < ApplicationController
      include IgnoreNotFound

      before_action(only: %i[get_appeal]) { authorize :appeals, :access? }
      before_action(only: %i[get_claim]) { authorize :lighthouse, :access? }
      before_action(only: %i[request_decision]) { authorize :lighthouse, :access? }
      before_action(only: %i[upload_document upload_multi_image_document]) { authorize :lighthouse, :access? }

      after_action(only: :upload_multi_image_document) { lighthouse_document_service.cleanup_after_upload }

      def index
        json, status = prepare_claims_and_appeals
        render json:, status:
      end

      def get_claim
        claim_detail = lighthouse_claims_adapter.parse(lighthouse_claims_proxy.get_claim(params[:id]))
        render json: Mobile::V0::ClaimSerializer.new(claim_detail)
      end

      def get_appeal
        appeal = claims_proxy.get_appeal(params[:id])

        begin
          appeal = appeal_adapter.parse(appeal) if Flipper.enabled?(:mobile_appeal_model, @current_user)
        rescue => e
          Rails.logger.info('MOBILE APPEAL VALIDATION ERROR', error: e.message)
        end

        render json: Mobile::V0::AppealSerializer.new(appeal)
      end

      def request_decision
        response = lighthouse_claims_proxy.request_decision(params[:id])
        jid = adapt_response(response)

        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_document
        set_params
        jid = lighthouse_document_service.queue_document_upload(params)

        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_multi_image_document
        set_params
        jid = lighthouse_document_service.queue_multi_image_upload_document(params)

        render json: { data: { job_id: jid } }, status: :accepted
      end

      def claim_letter_documents_search
        response = lighthouse_document_service.claim_letters_search(participant_id: @current_user.participant_id)
        documents = claim_letter_documents_adapter.parse(response.body)
        render json: Mobile::V0::ClaimLetterDocumentSerializer.new(documents)
      end

      def claim_letter_document_download
        # Backwards Compatibility: Delete {} brackets from document id as the
        # benefit documents service doesn't support them
        response = lighthouse_document_service.claim_letter_download(document_uuid: params[:document_id].delete('{}'),
                                                                     participant_id: @current_user.participant_id)
        send_data(
          response.body,
          type: 'application/pdf',
          filename: file_name
        )
      end

      private

      def set_params
        params[:claim_id] = params[:id]
        params[:tracked_item_ids] = Array.wrap(tracked_item_id) if tracked_item_id.present?
        params.delete(:tracked_item_id)
        params.delete(:trackedItemId)
      end

      # It was found that FE is using both different casing between multi image upload and single image upload.
      # This shouldn't matter due to the x-key-inflection: camel header being used but that header only works if the
      # body payload is in json, which the single doc upload is not (at least in specs for both LH and EVSS).
      def tracked_item_id
        params[:trackedItemId] || params[:tracked_item_id]
      end

      def file_name
        params.require(:file_name)
      end

      def prepare_claims_and_appeals
        list, errors = fetch_claims_and_appeals
        status = get_response_status(errors)
        list = filter_by_date(validated_params[:start_date], validated_params[:end_date], list)
        list = filter_by_completed(list) if params[:showCompleted].present?
        log_decision_letter_sent(list) if Flipper.enabled?(:mobile_claims_log_decision_letter_sent)
        active_claim_count = active_claims_count(list)
        list, meta = paginate(list, validated_params)

        options = {
          meta: {
            errors:, pagination: meta.dig(:meta, :pagination), active_claims_count: active_claim_count
          },
          links: meta[:links]
        }

        [Mobile::V0::ClaimOverviewSerializer.new(list, options), status]
      end

      def log_decision_letter_sent(list)
        decision_letters_sent = list.select(&:decision_letter_sent)

        return nil if decision_letters_sent.empty?

        claims_decision_letters_sent = decision_letters_sent.count { |item| item.type == 'claim' }
        appeals_decision_letters_sent = decision_letters_sent.count { |item| item.type == 'appeal' }

        Rails.logger.info('MOBILE CLAIM DECISION LETTERS SENT COUNT',
                          user_uuid: @current_user.uuid,
                          user_icn: @current_user.icn,
                          claims_decision_letter_sent_count: claims_decision_letters_sent,
                          appeals_decision_letter_sent_count: appeals_decision_letters_sent,
                          decision_letter_sent_ids: decision_letters_sent.map(&:id))
      end

      def fetch_claims_and_appeals
        use_cache = validated_params[:use_cache]
        service_list, service_errors = claims_index_interface.get_accessible_claims_appeals(use_cache)

        [service_list, service_errors]
      end

      def lighthouse_claims_adapter
        Mobile::V0::Adapters::LighthouseIndividualClaims.new
      end

      def appeal_adapter
        Mobile::V0::Adapters::Appeal.new
      end

      def claim_letter_documents_adapter
        Mobile::V0::Adapters::ClaimLetterDocuments
      end

      def lighthouse_claims_proxy
        Mobile::V0::LighthouseClaims::Proxy.new(@current_user)
      end

      def claims_proxy
        @claims_proxy ||= Mobile::V0::Claims::Proxy.new(@current_user)
      end

      def lighthouse_document_service
        @lighthouse_document_service ||= BenefitsDocuments::Service.new(@current_user)
      end

      def claims_index_interface
        @claims_index_interface ||= Mobile::V0::LighthouseClaims::ClaimsIndexInterface.new(@current_user)
      end

      def validated_params
        @validated_params ||= Mobile::V0::Contracts::ClaimsAndAppeals.new.call(pagination_params)
      end

      def paginate(list, validated_params)
        Mobile::PaginationHelper.paginate(list:, validated_params:)
      end

      def pagination_params
        pagination_params = {
          start_date: params[:startDate] || DateTime.new(1700).iso8601,
          end_date: params[:endDate] || (DateTime.now.utc.beginning_of_day + 1.year).iso8601,
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          use_cache: params[:useCache] || true
        }
        pagination_params[:show_completed] = params[:showCompleted] if params[:showCompleted].present?
        pagination_params
      end

      def get_response_status(errors)
        case errors.size
        when 1
          :multi_status
        when 2
          :bad_gateway
        else
          :ok
        end
      end

      def filter_by_date(start_date, end_date, list)
        list.filter do |entry|
          updated_at = entry[:updated_at]

          next(true) unless updated_at

          updated_at >= start_date && updated_at <= end_date
        end
      end

      def filter_by_completed(list)
        list.filter do |entry|
          entry[:completed] == ActiveRecord::Type::Boolean.new.deserialize(params[:showCompleted])
        end
      end

      def adapt_response(response)
        response['success'] ? 'success' : 'failure'
      end

      def active_claims_count(list)
        list.count { |item| item.completed == false }
      end
    end
  end
end
