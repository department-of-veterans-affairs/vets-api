# frozen_string_literal: true

require 'debts_api/v0/digital_dispute_submission_service'
require 'sidekiq/attr_package'

module DebtsApi
  module V0
    class DigitalDisputesController < ApplicationController
      service_tag 'debt-resolution'

      def create
        StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.initiated")
        Flipper.enabled?(:digital_dmc_dispute_service, current_user) ? create_via_dmc! : create_legacy!
      end

      private

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

      def create_legacy!
        result = process_submission
        if result[:success]
          render json: { message: result[:message], submission_id: result[:submission_id] }, status: :ok
        else
          StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.failure")
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      def initialize_submission
        DebtsApi::V0::DigitalDisputeSubmission.new(
          user_uuid: current_user.uuid,
          user_account: current_user.user_account,
          state: :pending,
          metadata: submission_params[:metadata]
        ).tap { |s| s.files.attach(submission_params[:files]) }
      end

      def render_validation_error(record)
        render json: { success: false, error_type: 'validation_error', errors: record.errors.to_hash(true) },
               status: :unprocessable_entity
      end

      def process_submission
        metadata = parse_metadata

        service = DebtsApi::V0::DigitalDisputeSubmissionService.new(
          current_user,
          submission_params[:files],
          metadata
        )
        service.call
      end

      def parse_metadata
        JSON.parse(submission_params[:metadata], symbolize_names: true)
      end

      def submission_params
        params.require(:metadata).permit(
          disputes: [
            :composite_debt_id,
            :deduction_code,
            :original_ar,
            :current_ar,
            :benefit_type,
            :dispute_reason,
            :rcvbl_id
          ],
          files: []
        )
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
