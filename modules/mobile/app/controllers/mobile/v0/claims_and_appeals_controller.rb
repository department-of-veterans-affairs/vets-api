# frozen_string_literal: true

require_relative '../../../models/mobile/v0/adapters/claims_overview'
require_relative '../../../models/mobile/v0/adapters/claims_overview_errors'
require_relative '../../../models/mobile/v0/claim_overview'
require_relative '../../../services/mobile/v0/lighthouse_claims/service_authorization_interface'
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

      before_action(only: %i[get_claim]) { service_authorization_interface.claims_access? }

      before_action(only: %i[request_decision]) { service_authorization_interface.request_decision_access? }

      before_action(only: %i[upload_document upload_multi_image_document]) do
        service_authorization_interface.upload_document_access?
      end

      after_action(only: :upload_multi_image_document) { service_authorization_interface.cleanup_after_upload }

      def index
        json, status = prepare_claims_and_appeals
        render json:, status:
      end

      def get_claim
        render json: Mobile::V0::ClaimSerializer.new(service_authorization_interface.get_claim)
      end

      def get_appeal
        appeal = service_authorization_interface.evss_claims_proxy.get_appeal(params[:id])
        render json: Mobile::V0::AppealSerializer.new(appeal)
      end

      def request_decision
        jid = service_authorization_interface.request_decision(params[:id])
        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_document
        jid = service_authorization_interface.upload_document
        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_multi_image_document
        jid = service_authorization_interface.upload_multi_image_document
        render json: { data: { job_id: jid } }, status: :accepted
      end

      private

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
        service_list, service_errors = service_authorization_interface.get_accessible_claims_appeals(use_cache)

        unless service_authorization_interface.non_authorization_errors?(service_errors)
          Mobile::V0::ClaimOverview.set_cached(@current_user, service_list)
        end

        [service_list, service_errors]
      end

      def validated_params
        @validated_params ||= Mobile::V0::Contracts::ClaimsAndAppeals.new.call(pagination_params)
      end

      def service_authorization_interface
        @appointments_cache_interface ||= Mobile::ServiceAuthorizationInterface.new(@current_user)
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

      def active_claims_count(list)
        list.count { |item| item.completed == false }
      end
    end
  end
end
