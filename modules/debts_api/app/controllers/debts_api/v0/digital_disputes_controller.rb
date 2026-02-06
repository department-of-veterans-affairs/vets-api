# frozen_string_literal: true

require 'debt_management_center/debts_service'
require 'sidekiq/attr_package'

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      include DebtsApi::Concerns::SubmissionValidation

      service_tag 'debt-resolution'
      before_action :authorize_icn

      before_action :parse_metadata, only: [:create]

      def create
        StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.initiated")
        create_via_dmc!
      end

      private

      def authorize_icn
        raise Common::Exceptions::Forbidden, detail: 'User ICN is required' if current_user.icn.blank?
      end

      def create_via_dmc!
        submission = initialize_submission

        begin
          submission.save!
          send_submission_email if email_notifications_enabled?
          DebtsApi::V0::DigitalDisputeJob.perform_async(submission.id)

          render json: { message: 'Submission received', submission_id: submission.guid }, status: :ok
        rescue ActiveRecord::RecordInvalid => e
          StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
          errors_hash = e.record.errors.to_hash
          Rails.logger.error(
            "DigitalDisputeController#create validation error: #{errors_hash.values.flatten.to_sentence}"
          )
          render json: { errors: errors_hash }, status: :unprocessable_entity
        rescue => e
          submission.clean_up_failure

          Rails.logger.error("DigitalDisputeController#create error: #{e.message} #{e.backtrace&.take(12)&.join("\n")}")

          StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
          render json: { errors: { base: [e.message] } }, status: :unprocessable_entity
        end
      end

      def initialize_submission
        DebtsApi::V0::DigitalDisputeSubmission.new(
          user_uuid: current_user.uuid,
          user_account: current_user.user_account,
          state: :pending,
          metadata: @parsed_metadata.to_json
        ).tap { |s| s.files.attach(submission_params[:files]) }
      end

      def parse_metadata
        @parsed_metadata = DebtsApi::Concerns::SubmissionValidation::DisputeDebtValidator
                           .parse_and_validate_metadata(
                             submission_params[:metadata],
                             user: current_user
                           )
      rescue ArgumentError => e
        StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
        Rails.logger.error("DigitalDisputeController#parse_metadata validation error: #{e.message}")
        render json: { errors: { metadata: [e.message] } }, status: :unprocessable_entity
      end

      def submission_params
        {
          metadata: params.require(:metadata),
          files: params[:files] || []
        }
      end

      def email_notifications_enabled?
        Flipper.enabled?(:digital_dispute_email_notifications, current_user) && current_user.email.present?
      end

      def send_submission_email
        cache_key = Sidekiq::AttrPackage.create(email: current_user.email, first_name: current_user.first_name)
        DebtsApi::V0::Form5655::SendConfirmationEmailJob.perform_in(
          5.minutes,
          {
            'submission_type' => 'digital_dispute',
            'cache_key' => cache_key,
            'user_uuid' => current_user.uuid,
            'template_id' => DebtsApi::V0::DigitalDisputeSubmission::SUBMISSION_TEMPLATE
          }
        )
      end
    end
  end
end
