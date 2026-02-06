# frozen_string_literal: true

require 'dgi/claimant/service'
require 'dgi/letters/service'
require 'dgi/status/service'

module MebApi
  module V0
    class BaseController < ::ApplicationController
      service_tag 'education-benefits'
      before_action :authorize_access

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

      def log_missing_email_attributes(form_tag, missing_attributes, status, email, first_name)
        Rails.logger.warn(
          "#{form_tag} confirmation email skipped due to missing attributes",
          { status_present: status.present?, email_present: email.present?, first_name_present: first_name.present? }
        )
        StatsD.increment('api.meb.confirmation_email.skipped', tags: ["form:#{form_tag}", 'reason:missing_attributes'])
        render json: { error: 'Missing required attributes for confirmation email', missing_attributes: },
               status: :unprocessable_entity
      end

      def log_submission_error(error, log_message)
        cached_error_class = error.class.name
        cached_response_body = error.body if error.respond_to?(:body)

        log_params = {
          icn: @current_user.icn,
          error_class: cached_error_class,
          error_message: error.message.presence || 'No error message provided',
          request_id: request.request_id
        }

        # Only log response details for ClientError (downstream service failures).
        # Response body truncated to 250 chars to limit log size while preserving debug context.
        if error.is_a?(Common::Client::Errors::ClientError)
          log_params[:status] = error.status
          log_params[:response_body] = cached_response_body&.to_s&.truncate(250) if cached_response_body.present?
        end

        Rails.logger.error(log_message, log_params)

        # Increment metrics for monitoring/alerting
        StatsD.increment('api.meb.submit_claim.error', tags: ["error_class:#{cached_error_class}"])
      end
    end
  end
end
