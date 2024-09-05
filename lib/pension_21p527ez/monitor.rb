# frozen_string_literal: true

module Pension21p527ez
  class Monitor
    CLAIM_STATS_KEY = 'api.pension_claim'
    SUBMISSION_STATS_KEY = 'worker.lighthouse.pension_benefit_intake_job'

    def track_show404(confirmation_number, current_user, e)
      Rails.logger.error('21P-527EZ submission not found',
                         { confirmation_number:, user_uuid: current_user&.uuid, message: e&.message })
    end

    def track_show_error(confirmation_number, current_user, e)
      Rails.logger.error('21P-527EZ fetching submission failed',
                         { confirmation_number:, user_uuid: current_user&.uuid, message: e&.message })
    end

    def track_create_attempt(claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.attempt")
      Rails.logger.info('21P-527EZ submission to Sidekiq begun',
                        { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid })
    end

    def track_create_error(in_progress_form, claim, current_user, e = nil)
      StatsD.increment("#{CLAIM_STATS_KEY}.failure")
      Rails.logger.error('21P-527EZ submission to Sidekiq failed',
                         { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                           in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                           message: e&.message })
    end

    def track_create_success(in_progress_form, claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.success")
      if claim.form_start_date
        StatsD.measure('saved_claim.time-to-file', claim.created_at - claim.form_start_date,
                       tags: ["form_id:#{claim.form_id}"])
      end
      Rails.logger.info('21P-527EZ submission to Sidekiq success',
                        { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                          in_progress_form_id: in_progress_form&.id })
    end

    def track_submission_begun(claim, lighthouse_service, user_uuid)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.begun")
      Rails.logger.info('Lighthouse::PensionBenefitIntakeJob submission to LH begun',
                        {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_uuid:
                        })
    end

    def track_submission_attempted(claim, lighthouse_service, user_uuid, upload)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.attempt")
      Rails.logger.info('Lighthouse::PensionBenefitIntakeJob submission to LH attempted', {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_uuid:,
                          file: upload[:file],
                          attachments: upload[:attachments]
                        })
    end

    def track_submission_success(claim, lighthouse_service, user_uuid)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.success")
      Rails.logger.info('Lighthouse::PensionBenefitIntakeJob submission to LH succeeded', {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_uuid:
                        })
    end

    def track_submission_retry(claim, lighthouse_service, user_uuid, e)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.failure")
      Rails.logger.warn('Lighthouse::PensionBenefitIntakeJob submission to LH failed, retrying', {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_uuid:,
                          message: e&.message
                        })
    end

    def track_submission_exhaustion(msg, claim = nil)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error('Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!', {
                           claim_id: msg['args'].first,
                           confirmation_number: claim&.confirmation_number,
                           user_uuid: msg['args'].length <= 1 ? nil : msg['args'][1],
                           message: msg
                         })
    end

    def track_file_cleanup_error(claim, lighthouse_service, user_uuid, e)
      Rails.logger.error('Lighthouse::PensionBenefitIntakeJob cleanup failed',
                         {
                           claim_id: claim&.id,
                           benefits_intake_uuid: lighthouse_service&.uuid,
                           confirmation_number: claim&.confirmation_number,
                           user_uuid:,
                           error: e&.message
                         })
    end
  end
end
