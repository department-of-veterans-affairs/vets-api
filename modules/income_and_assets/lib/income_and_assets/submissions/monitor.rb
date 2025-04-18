# frozen_string_literal: true
require 'zero_silent_failures/monitor'

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
        StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
        Rails.logger.error('IncomeAndAssets::BenefitIntakeJob submission to LH exhausted!', {
                             claim_id: msg['args'].first,
                             confirmation_number: claim&.confirmation_number,
                             message: msg,
                             user_account_uuid: msg['args'].length <= 1 ? nil : msg['args'][1]
                           })
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
