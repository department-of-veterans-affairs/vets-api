# frozen_string_literal: true

module V0
  module Profile
    class PaymentHistoryController < ApplicationController
      service_tag 'payment-history'
      before_action :check_policy_requirements
      before_action { authorize :bgs, :access? }

      def index
        payment_history = PaymentHistory.new(payments: adapter.payments, return_payments: adapter.return_payments)
        render json: PaymentHistorySerializer.new(payment_history)
      end

      private

      def adapter
        @adapter ||= Adapters::PaymentHistoryAdapter.new(bgs_service_response)
      end

      def bgs_service_response
        person = fetch_person_from_bgs
        payment_history = fetch_payment_history_from_bgs(person)

        if payment_history.nil?
          Rails.logger.error('BGS::PaymentService returned nil',
                             person_status: person&.status,
                             user_uuid: current_user&.uuid)
          StatsD.increment('api.payment_history.nil_payment_history')
        end

        payment_history
      end

      # Check BGS Policy requirements - logs missing attributes
      # Future: Could raise error if attributes missing
      def check_policy_requirements
        missing_attributes = []
        missing_attributes << 'icn' unless current_user&.icn.present?
        missing_attributes << 'ssn' unless current_user&.ssn.present?
        missing_attributes << 'participant_id' unless current_user&.participant_id.present?

        if missing_attributes.any?
          Rails.logger.warn('BGS Policy: Missing required attributes',
                            user_uuid: current_user&.uuid,
                            missing_attributes:,
                            loa3: current_user&.loa3?)
          missing_attributes.each do |attr|
            StatsD.increment("api.payment_history.policy.missing_#{attr}")
          end
        end
      end

      # Fetch person from BGS People Request API
      # Future: Could validate person response and required fields
      def fetch_person_from_bgs
        person = BGS::People::Request.new.find_person_by_participant_id(user: current_user)

        validate_person_response(person)
        person
      rescue => e
        handle_bgs_people_error(e)
        raise
      end

      # Validate person response has required fields
      def validate_person_response(person)
        if person.nil?
          Rails.logger.error('BGS People Request returned nil',
                             user_uuid: current_user&.uuid,
                             participant_id: current_user&.participant_id)
          StatsD.increment('api.payment_history.bgs_people.nil_response')
          return
        end

        # Check status
        unless person.status == :ok
          Rails.logger.warn('BGS People Request non-OK status',
                            user_uuid: current_user&.uuid,
                            status: person.status)
          StatsD.increment('api.payment_history.bgs_people.bad_status')
        end

        # Check required fields for payment_history call
        missing_fields = []
        missing_fields << 'file_number' unless person.file_number.present?
        missing_fields << 'participant_id' unless person.participant_id.present?
        missing_fields << 'ssn_number' unless person.ssn_number.present?

        if missing_fields.any?
          Rails.logger.warn('BGS People Request: Missing required fields',
                            user_uuid: current_user&.uuid,
                            missing_fields:)
          missing_fields.each { |field| StatsD.increment("api.payment_history.bgs_people.missing_#{field}") }
        end
      end

      # Handle BGS People Request errors
      def handle_bgs_people_error(error)
        Rails.logger.error('BGS People Request failed',
                           user_uuid: current_user&.uuid,
                           participant_id: current_user&.participant_id,
                           error_class: error.class.name,
                           error_message: error.message)
        StatsD.increment('api.payment_history.bgs_people.failed')
        StatsD.increment("api.payment_history.bgs_people.failed.#{error.class.name.underscore}")
      end

      # Fetch payment history from BGS Payment Service API
      # Future: Could validate payment response structure
      def fetch_payment_history_from_bgs(person)
        payment_history = BGS::PaymentService.new(current_user).payment_history(person)

        validate_payment_response(payment_history)
        payment_history
      rescue => e
        handle_bgs_payment_error(e)
        raise
      end

      # Validate payment history response
      def validate_payment_response(payment_history)
        if payment_history.nil?
          Rails.logger.warn('BGS Payment Service returned nil',
                            user_uuid: current_user&.uuid)
          StatsD.increment('api.payment_history.bgs_payment.nil_response')
          return
        end

        # Check response structure
        unless payment_history.is_a?(Hash) && payment_history.key?(:payments)
          Rails.logger.warn('BGS Payment Service: Unexpected response structure',
                            user_uuid: current_user&.uuid,
                            response_class: payment_history.class.name)
          StatsD.increment('api.payment_history.bgs_payment.malformed_response')
          return
        end

        # Count raw payments
        payments_data = payment_history.dig(:payments, :payment)
        raw_count = if payments_data.is_a?(Array)
                      payments_data.length
                    elsif payments_data.present?
                      1
                    else
                      0
                    end

        StatsD.gauge('api.payment_history.bgs_payment.raw_count', raw_count)
        Rails.logger.info('BGS Payment Service response received',
                          user_uuid: current_user&.uuid,
                          raw_payment_count: raw_count)
      end

      # Handle BGS Payment Service errors
      def handle_bgs_payment_error(error)
        Rails.logger.error('BGS Payment Service failed',
                           user_uuid: current_user&.uuid,
                           error_class: error.class.name,
                           error_message: error.message)
        StatsD.increment('api.payment_history.bgs_payment.failed')
        StatsD.increment("api.payment_history.bgs_payment.failed.#{error.class.name.underscore}")
      end
    end
  end
end
