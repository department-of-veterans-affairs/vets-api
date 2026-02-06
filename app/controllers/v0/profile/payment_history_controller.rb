# frozen_string_literal: true

module V0
  module Profile
    class PaymentHistoryController < ApplicationController
      service_tag 'payment-history'
      before_action :log_access_attempt
      before_action :validate_user_identifiers
      before_action { authorize :bgs, :access? }

      def index
        log_authorized_access
        payment_history = PaymentHistory.new(payments: adapter.payments, return_payments: adapter.return_payments)
        validate_final_response(payment_history)
        render json: PaymentHistorySerializer.new(payment_history)
      rescue => e
        log_payment_history_exception(e)
        raise
      end

      private

      def adapter
        @adapter ||= Adapters::PaymentHistoryAdapter.new(bgs_service_response)
      end

      def bgs_service_response
        validate_user_for_bgs

        log_before_bgs_people_request
        person = BGS::People::Request.new.find_person_by_participant_id(user: current_user)
        log_after_bgs_people_request

        validate_person_attributes(person)

        log_before_bgs_payment_service_request
        payment_history = BGS::PaymentService.new(current_user).payment_history(person)
        log_after_bgs_payment_service_request

        validate_payment_history(payment_history, person)

        payment_history
      end

      # Detailed logging functions for drop off tracking.

      def log_access_attempt
        return unless Flipper.enabled?(:payment_history_detailed_logging)

        StatsD.increment('api.payment_history.access_attempt')
        Rails.logger.info('User attempting to access BGS payment history', {
                            user_uuid: current_user&.uuid
                          })
      end

      def log_authorized_access
        return unless Flipper.enabled?(:payment_history_detailed_logging)

        StatsD.increment('api.payment_history.authorized')
        Rails.logger.info('User authorized for BGS payment history access', {
                            user_uuid: current_user&.uuid
                          })
      end

      def log_before_bgs_people_request
        return unless Flipper.enabled?(:payment_history_detailed_logging)

        StatsD.increment('api.payment_history.bgs_people_request.started')
        Rails.logger.info('Requesting person from BGS', {
                            user_uuid: current_user&.uuid
                          })
      end

      def log_after_bgs_people_request
        return unless Flipper.enabled?(:payment_history_detailed_logging)

        StatsD.increment('api.payment_history.bgs_people_request.completed')
        Rails.logger.info('Received person from BGS', {
                            user_uuid: current_user&.uuid
                          })
      end

      def log_before_bgs_payment_service_request
        return unless Flipper.enabled?(:payment_history_detailed_logging)

        StatsD.increment('api.payment_history.bgs_payment_service.started')
        Rails.logger.info('Requesting payment history from BGS', {
                            user_uuid: current_user&.uuid
                          })
      end

      def log_after_bgs_payment_service_request
        return unless Flipper.enabled?(:payment_history_detailed_logging)

        StatsD.increment('api.payment_history.bgs_payment_service.completed')
        Rails.logger.info('Received payment history from BGS', {
                            user_uuid: current_user&.uuid
                          })
      end

      # Validation logging functions for tracking existence of required attributes for services.

      def validate_user_for_bgs
        return unless Flipper.enabled?(:payment_history_validation_logging)

        # Identifier check - ensure user has at least one identifier
        if current_user&.icn.blank? && current_user&.uuid.blank?
          Rails.logger.error('User missing both ICN and UUID identifiers', {
                               user_uuid: current_user&.uuid
                             })
          StatsD.increment('api.payment_history.user.no_identifiers')
        end

        # Additional identifier check - ensure user has contact information for BGS service
        # BGS::PaymentService uses common_name.presence || email for external_key
        if current_user&.common_name.blank? && current_user&.email.blank?
          Rails.logger.error('User missing all contact identifiers (common_name, email)', {
                               user_uuid: current_user&.uuid,
                               va_profile_email_present: current_user&.va_profile_email.present?
                             })
          StatsD.increment('api.payment_history.user.no_contact_identifiers')
        end
      end

      def validate_user_identifiers
        return unless Flipper.enabled?(:payment_history_validation_logging)

        missing = []

        missing << 'ICN' if current_user&.icn.blank?
        missing << 'SSN' if current_user&.ssn.blank?
        missing << 'participant_id' if current_user&.participant_id.blank?

        if missing.any?
          Rails.logger.warn('User missing required identifiers for BGS payment history', {
                              user_uuid: current_user&.uuid,
                              missing_identifiers: missing.join(', ')
                            })
          StatsD.increment('api.payment_history.missing_identifiers')
        end
      end

      def validate_person_attributes(person)
        return unless Flipper.enabled?(:payment_history_validation_logging)

        if person.nil?
          Rails.logger.error('BGS::People::Request returned nil person', {
                               user_uuid: current_user&.uuid
                             })
          StatsD.increment('api.payment_history.bgs_person.nil')
          return
        end

        missing = []
        missing << 'status' if person&.status.blank?
        missing << 'file_number' if person&.file_number.blank?
        missing << 'participant_id' if person&.participant_id.blank?
        missing << 'ssn_number' if person&.ssn_number.blank?

        if missing.any?
          Rails.logger.warn('BGS person missing required attributes', {
                              user_uuid: current_user&.uuid,
                              missing_attributes: missing.join(', ')
                            })
          StatsD.increment('api.payment_history.bgs_person.missing_attributes')
        end
      end

      def validate_payment_history(payment_history, person)
        return unless Flipper.enabled?(:payment_history_validation_logging)

        if payment_history.nil?
          Rails.logger.error('BGS::PaymentService returned nil', {
                               person_status: person&.status,
                               user_uuid: current_user&.uuid
                             })
          StatsD.increment('api.payment_history.payment_history.nil')
          return
        end

        if payment_history&.payments.blank?
          Rails.logger.warn('BGS payment history has no payments', {
                              user_uuid: current_user&.uuid
                            })
          StatsD.increment('api.payment_history.payments.empty')
        end
      end

      def validate_final_response(payment_history)
        return unless Flipper.enabled?(:payment_history_validation_logging)

        payments_empty = payment_history&.payments.blank?
        return_payments_empty = payment_history&.return_payments.blank?

        if payments_empty && return_payments_empty
          Rails.logger.warn('Returning empty payment history response to customer', {
                              user_uuid: current_user&.uuid
                            })
          StatsD.increment('api.payment_history.response.empty')
        else
          Rails.logger.info('Returning payment history response to customer', {
                              user_uuid: current_user&.uuid
                            })
          StatsD.increment('api.payment_history.response.success')
        end
      end

      # Exception logging function. For logging exceptions information and tracking exception drop off.

      def log_payment_history_exception(exception)
        return unless Flipper.enabled?(:payment_history_exception_logging)

        exception_class = exception&.class&.name
        Rails.logger.error('Exception occurred in payment history controller', {
                             user_uuid: current_user&.uuid,
                             exception_class:,
                             exception_message: exception&.message
                           })
        StatsD.increment("api.payment_history.exception.#{exception_class&.underscore}")
      end
    end
  end
end
