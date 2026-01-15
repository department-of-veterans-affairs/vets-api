# frozen_string_literal: true

require 'dgi/claimant/service'
require 'dgi/letters/service'
require 'dgi/status/service'
require 'meb_api/confirmation_email_config'

module MebApi
  module V0
    class BaseController < ::ApplicationController
      service_tag 'education-benefits'
      before_action :authorize_access

      STATS_KEY = 'api.meb.confirmation_email'

      private

      def authorize_access
        authorize(current_user, :access?, policy_class: MebPolicy)
      end

      def check_forms_flipper
        routing_error unless Flipper.enabled?(:show_forms_app)
      end

      def claim_status_service
        MebApi::DGI::Status::Service.new(@current_user)
      end

      def claim_letters_service
        MebApi::DGI::Letters::Service.new(@current_user)
      end

      def claimant_service
        MebApi::DGI::Claimant::Service.new(@current_user)
      end

      # Shared confirmation email logging methods
      def log_confirmation_email_request(form_tag, flipper_key)
        Rails.logger.info(
          'MEB confirmation email endpoint called',
          {
            form_tag:,
            flipper_enabled: Flipper.enabled?(flipper_key),
            params_claim_status: params[:claim_status],
            params_email_present: params[:email].present?,
            user_email_present: @current_user.email.present?
          }
        )
      end

      def log_confirmation_email_skipped(form_tag, reason, status = nil)
        Rails.logger.warn(
          'MEB confirmation email skipped',
          {
            form_tag:,
            reason:,
            claim_status: status
          }.compact
        )
        StatsD.increment("#{STATS_KEY}.skipped", tags: [form_tag, "reason:#{reason}"])
      end

      def log_confirmation_email_dispatched(form_tag, status)
        normalized_status = MebApi::ConfirmationEmailConfig.normalize_claim_status(status)
        Rails.logger.info(
          'MEB confirmation email worker dispatched',
          {
            form_tag:,
            claim_status: status
          }
        )
        StatsD.increment("#{STATS_KEY}.dispatched",
                         tags: [form_tag, "claim_status:#{normalized_status}"])
      end
    end
  end
end
