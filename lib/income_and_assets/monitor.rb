# frozen_string_literal: true

module IncomeAndAssets
  class Monitor
    CLAIM_STATS_KEY = 'api.income_and_assets'
    SUBMISSION_STATS_KEY = 'worker.income_and_assets_intake_job'

    def track_show404(confirmation_number, user_account_uuid, e)
      context = {
        confirmation_number:,
        user_account_uuid:,
        message: e&.message
      }
      Rails.logger.error('21P-0969 submission not found', context)
    end

    def track_show_error(confirmation_number, user_account_uuid, e)
      context = {
        confirmation_number:,
        user_account_uuid:,
        message: e&.message
      }
      Rails.logger.error('21P-0969 fetching submission failed', context)
    end

    def track_create_attempt(claim, user_account_uuid)
      StatsD.increment("#{CLAIM_STATS_KEY}.attempt")
      context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:
      }
      Rails.logger.info('21P-0969 submission to Sidekiq begun', context)
    end

    def track_create_error(in_progress_form_id, claim, user_account_uuid, e = nil)
      StatsD.increment("#{CLAIM_STATS_KEY}.failure")
      context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        in_progress_form_id:,
        errors: claim&.errors&.errors,
        message: e&.message
      }
      Rails.logger.error('21P-0969 submission to Sidekiq failed', context)
    end

    def track_create_success(in_progress_form_id, claim, user_account_uuid)
      StatsD.increment("#{CLAIM_STATS_KEY}.success")
      if claim.form_start_date
        StatsD.measure('saved_claim.time-to-file', claim.created_at - claim.form_start_date,
                       tags: ["form_id:#{claim.form_id}"])
      end
      Rails.logger.info('21P-0969 submission to Sidekiq success',
                        { confirmation_number: claim&.confirmation_number, user_account_uuid:,
                          in_progress_form_id: })
    end

    def track_submission_begun(claim, lighthouse_service, user_account_uuid)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.begun")
      Rails.logger.info('Lighthouse::IncomeAndAssetsIntakeJob submission to LH begun',
                        {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_account_uuid:
                        })
    end

    def track_submission_attempted(claim, lighthouse_service, user_account_uuid, payload)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.attempt")
      Rails.logger.info('Lighthouse::IncomeAndAssetsIntakeJob submission to LH attempted', {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_account_uuid:,
                          file: payload[:file],
                          attachments: payload[:attachments]
                        })
    end

    def track_submission_success(claim, lighthouse_service, user_account_uuid)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.success")
      Rails.logger.info('Lighthouse::IncomeAndAssetsIntakeJob submission to LH succeeded', {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_account_uuid:
                        })
    end

    def track_submission_retry(claim, lighthouse_service, user_account_uuid, e)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.failure")
      Rails.logger.warn('Lighthouse::IncomeAndAssetsIntakeJob submission to LH failed, retrying', {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_account_uuid:,
                          message: e&.message
                        })
    end

    def track_submission_exhaustion(msg, claim = nil)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error('Lighthouse::IncomeAndAssetsIntakeJob submission to LH exhausted!', {
                           claim_id: msg['args'].first,
                           confirmation_number: claim&.confirmation_number,
                           message: msg,
                           user_account_uuid: msg['args'].length <= 1 ? nil : msg['args'][1]
                         })
    end

    def track_file_cleanup_error(claim, lighthouse_service, user_account_uuid, e)
      Rails.logger.error('Lighthouse::IncomeAndAssetsIntakeJob cleanup failed',
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
