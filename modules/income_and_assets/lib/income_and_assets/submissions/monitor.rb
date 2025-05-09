# frozen_string_literal: true

require 'zero_silent_failures/monitor'
require 'income_and_assets/notification_email'

module IncomeAndAssets
  ##
  # IncomeAndAssets sidekiq monitor functions for Rails logging and StatsD
  #
  module Submissions
    ##
    # Monitor functions for Rails logging and StatsD
    #
    class Monitor < ::ZeroSilentFailures::Monitor
      # statsd key for sidekiq
      SUBMISSION_STATS_KEY = 'worker.lighthouse.income_and_assets_intake_job'

      attr_reader :tags

      def initialize
        super('income-and-assets')

        @tags = ['form_id:21P-0969']
      end

      ##
      # log Sidkiq job started
      # @see IncomeAndAssetsIntakeJob
      #
      # @param claim [IncomeAndAssets::SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      #
      def track_submission_begun(claim, lighthouse_service, user_account_uuid)
        StatsD.increment("#{SUBMISSION_STATS_KEY}.begun")
        Rails.logger.info('IncomeAndAssets::BenefitIntakeJob submission to LH begun',
                          {
                            claim_id: claim&.id,
                            benefits_intake_uuid: lighthouse_service&.uuid,
                            confirmation_number: claim&.confirmation_number,
                            user_account_uuid:
                          })
      end

      ##
      # log Sidkiq job Lighthouse submission attempted
      # @see IncomeAndAssetsIntakeJob
      #
      # @param claim [IncomeAndAssets::SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      # @param payload [Hash] lighthouse upload data
      #
      def track_submission_attempted(claim, lighthouse_service, user_account_uuid, payload)
        StatsD.increment("#{SUBMISSION_STATS_KEY}.attempt")
        Rails.logger.info('IncomeAndAssets::BenefitIntakeJob submission to LH attempted', {
                            claim_id: claim&.id,
                            benefits_intake_uuid: lighthouse_service&.uuid,
                            confirmation_number: claim&.confirmation_number,
                            user_account_uuid:,
                            file: payload[:file],
                            attachments: payload[:attachments]
                          })
      end

      ##
      # log Sidkiq job completed
      # @see IncomeAndAssetsIntakeJob
      #
      # @param claim [IncomeAndAssets::SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      #
      def track_submission_success(claim, lighthouse_service, user_account_uuid)
        StatsD.increment("#{SUBMISSION_STATS_KEY}.success")
        Rails.logger.info('IncomeAndAssets::BenefitIntakeJob submission to LH succeeded', {
                            claim_id: claim&.id,
                            benefits_intake_uuid: lighthouse_service&.uuid,
                            confirmation_number: claim&.confirmation_number,
                            user_account_uuid:
                          })
      end

      ##
      # log Sidkiq job failed, automatic retry
      # @see IncomeAndAssetsIntakeJob
      #
      # @param claim [IncomeAndAssets::SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      # @param e [Error]
      #
      def track_submission_retry(claim, lighthouse_service, user_account_uuid, e)
        StatsD.increment("#{SUBMISSION_STATS_KEY}.failure")
        Rails.logger.warn('IncomeAndAssets::BenefitIntakeJob submission to LH failed, retrying', {
                            claim_id: claim&.id,
                            benefits_intake_uuid: lighthouse_service&.uuid,
                            confirmation_number: claim&.confirmation_number,
                            user_account_uuid:,
                            message: e&.message
                          })
      end

      ##
      # log Sidkiq job exhaustion, complete failure after all retries
      # @see IncomeAndAssetsIntakeJob
      #
      # @param msg [Hash] sidekiq exhaustion response
      # @param claim [IncomeAndAssets::SavedClaim]
      #
      def track_submission_exhaustion(msg, claim = nil)
        user_account_uuid = msg['args'].length <= 1 ? nil : msg['args'][1]
        additional_context = {
          confirmation_number: claim&.confirmation_number,
          user_account_uuid:,
          form_id: claim&.form_id,
          claim_id: msg['args'].first,
          message: msg,
          tags:
        }
        call_location = caller_locations.first

        if claim
          # silent failure tracking in email callback
          IncomeAndAssets::NotificationEmail.new(claim.id).deliver(:error)
        else
          log_silent_failure(additional_context, user_account_uuid, call_location:)
        end

        track_request('error', 'IncomeAndAssets::BenefitIntakeJob submission to LH exhausted!',
                      "#{SUBMISSION_STATS_KEY}.exhausted", call_location:, **additional_context)
      end

      ##
      # Tracks the failure to send a Submission in Progress email for a claim.
      # @see IncomeAndAssets::BenefitIntakeJob
      #
      # @param claim [IncomeAndAssets::SavedClaim]
      # @param lighthouse_service [LighthouseService]
      # @param e [Exception]
      #
      def track_send_submitted_email_failure(claim, lighthouse_service, user_account_uuid, e)
        additional_context = {
          confirmation_number: claim&.confirmation_number,
          user_account_uuid:,
          claim_id: claim&.id,
          benefits_intake_uuid: lighthouse_service&.uuid,
          message: e&.message,
          tags:
        }

        track_request('warn', 'IncomeAndAssets::BenefitIntakeJob send_submitted_email failed',
                      "#{SUBMISSION_STATS_KEY}.send_submitted_failed",
                      call_location: caller_locations.first, **additional_context)
      end

      ##
      # log Sidkiq job cleanup error occurred, this can occur post success or failure
      # @see IncomeAndAssetsIntakeJob
      #
      # @param claim [IncomeAndAssets::SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      # @param e [Error]
      #
      def track_file_cleanup_error(claim, lighthouse_service, user_account_uuid, e)
        Rails.logger.error('IncomeAndAssets::BenefitIntakeJob cleanup failed',
                           {
                             error: e&.message,
                             claim_id: claim&.id,
                             benefits_intake_uuid: lighthouse_service&.uuid,
                             confirmation_number: claim&.confirmation_number,
                             user_account_uuid:
                           })
      end
    end
  end
end
