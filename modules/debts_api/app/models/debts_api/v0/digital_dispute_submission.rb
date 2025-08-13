# frozen_string_literal: true

# rubocop:disable Rails/Pluck
module DebtsApi
  module V0
    class DigitalDisputeSubmission < ApplicationRecord
      STATS_KEY = 'api.digital_dispute_submission'
      CONFIRMATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.digital_dispute_confirmation_email
      FAILURE_TEMPLATE = Settings.vanotify.services.dmc.template_id.digital_dispute_failure_email
      self.table_name = 'digital_dispute_submissions'
      belongs_to :user_account, dependent: nil, optional: false
      has_kms_key
      has_encrypted :form_data, :metadata, key: :kms_key
      validates :user_uuid, presence: true
      enum :state, { pending: 0, submitted: 1, failed: 2 }

      def parsed_metadata
        return {} if metadata.blank?

        @parsed_metadata ||= JSON.parse(metadata, symbolize_names: true)
      rescue JSON::ParserError
        {}
      end

      def kms_encryption_context
        {
          model_name: 'DigitalDisputeSubmission',
          model_id: id
        }
      end

      def store_public_metadata
        return unless metadata

        disputes = parsed_metadata[:disputes] || []

        self.public_metadata = {
          'debt_types' => extract_debt_types(disputes),
          'dispute_reasons' => extract_dispute_reasons(disputes)
        }
      end

      def store_debt_identifiers(disputes)
        return unless disputes

        self.debt_identifiers = disputes.map { |d| d[:composite_debt_id] }.compact
      end

      def register_failure(message)
        failed!
        update(error_message: message)
        begin
          send_failure_email if Settings.vsp_environment == 'production'
        rescue => e
          StatsD.increment("#{STATS_KEY}.send_failed_form_email.enqueue.failure")
          Rails.logger.error("Failed to send failed form email: #{e.message}")
        end
      end

      def register_success
        submitted!
        send_success_email if Settings.vsp_environment == 'production'
      end

      private

      def extract_debt_types(disputes)
        disputes.map { |d| d[:debt_type] }.compact.uniq
      end

      def extract_dispute_reasons(disputes)
        disputes.map { |d| d[:dispute_reason] }.compact.uniq
      end

      def send_success_email
        user = User.find(user_uuid)
        return if user&.email.blank?

        DebtsApi::V0::Form5655::SendConfirmationEmailJob.perform_async(
          {
            'submission_type' => 'digital_dispute',
            'email' => user.email,
            'first_name' => user.first_name,
            'user_uuid' => user.uuid,
            'template_id' => CONFIRMATION_TEMPLATE
          }
        )
      rescue => e
        Rails.logger.error("Failed to send digital dispute success email: #{e.message}")
      end

      def send_failure_email
        StatsD.increment("#{STATS_KEY}.send_failed_form_email.enqueue")
        user = User.find(user_uuid)
        return if user&.email.blank?

        submission_email = user.email.downcase
        jid = DebtManagementCenter::VANotifyEmailJob.perform_in(
          24.hours,
          submission_email,
          FAILURE_TEMPLATE,
          failure_email_personalization_info(user),
          { id_type: 'email', failure_mailer: true }
        )

        Rails.logger.info("Failed digital dispute email enqueued form: #{id} email scheduled with jid: #{jid}")
      end

      def failure_email_personalization_info(user)
        {
          'first_name' => user.first_name,
          'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
          'updated_at' => updated_at,
          'confirmation_number' => id
        }
      end
    end
  end
end
# rubocop:enable Rails/Pluck
