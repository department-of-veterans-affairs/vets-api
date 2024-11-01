# frozen_string_literal: true

require 'pensions/notification_email'
require 'zero_silent_failures/monitor'

module Pensions
  ##
  # Monitor functions for Rails logging and StatsD
  # @todo abstract, split logging for controller and sidekiq
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.pension_claim'

    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'worker.lighthouse.pension_benefit_intake_job'

    def initialize
      super('pension-application')
    end

    ##
    # log GET 404 from controller
    # @see PensionClaimsController
    #
    # @param confirmation_number [UUID] saved_claim guid
    # @param current_user [User]
    # @param e [ActiveRecord::RecordNotFound]
    #
    def track_show404(confirmation_number, current_user, e)
      Rails.logger.error('21P-527EZ submission not found',
                         { confirmation_number:, user_uuid: current_user&.uuid, message: e&.message })
    end

    ##
    # log GET 500 from controller
    # @see PensionClaimsController
    #
    # @param confirmation_number [UUID] saved_claim guid
    # @param current_user [User]
    # @param e [Error]
    #
    def track_show_error(confirmation_number, current_user, e)
      Rails.logger.error('21P-527EZ fetching submission failed',
                         { confirmation_number:, user_uuid: current_user&.uuid, message: e&.message })
    end

    ##
    # log POST processing started
    # @see PensionClaimsController
    #
    # @param claim [Pension::SavedClaim]
    # @param current_user [User]
    #
    def track_create_attempt(claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.attempt")
      Rails.logger.info('21P-527EZ submission to Sidekiq begun',
                        { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                          statsd: "#{CLAIM_STATS_KEY}.attempt" })
    end

    ##
    # log POST claim save validation error
    # @see PensionClaimsController
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [Pension::SavedClaim]
    # @param current_user [User]
    # @param e [Error]
    #
    def track_create_validation_error(in_progress_form, claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.validation_error")
      Rails.logger.error('21P-527EZ submission validation error',
                         { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                           in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                           statsd: "#{CLAIM_STATS_KEY}.validation_error" })
    end

    ##
    # log POST processing failure
    # @see PensionClaimsController
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [Pension::SavedClaim]
    # @param current_user [User]
    # @param e [Error]
    #
    def track_create_error(in_progress_form, claim, current_user, e = nil)
      StatsD.increment("#{CLAIM_STATS_KEY}.failure")
      Rails.logger.error('21P-527EZ submission to Sidekiq failed',
                         { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                           in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                           message: e&.message, statsd: "#{CLAIM_STATS_KEY}.failure" })
    end

    ##
    # log POST processing success
    # @see PensionClaimsController
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [Pension::SavedClaim]
    # @param current_user [User]
    #
    def track_create_success(in_progress_form, claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.success")
      context = {
        confirmation_number: claim&.confirmation_number,
        user_uuid: current_user&.uuid,
        in_progress_form_id: in_progress_form&.id,
        statsd: "#{CLAIM_STATS_KEY}.success"
      }
      Rails.logger.info('21P-527EZ submission to Sidekiq success', context)
    end

    ##
    # log process_attachments! error
    # @see PensionClaimsController
    #
    # @param claim [Pension::SavedClaim]
    # @param current_user [User]
    # @param e [Error]
    #
    def track_process_attachment_error(in_progress_form, claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.process_attachment_error")
      Rails.logger.error('21P-527EZ process attachment error',
                         { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                           in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                           statsd: "#{CLAIM_STATS_KEY}.process_attachment_error" })
    end

    ##
    # log Sidkiq job started
    # @see PensionBenefitIntakeJob
    #
    # @param claim [Pension::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_uuid [UUID]
    #
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

    ##
    # log Sidkiq job Lighthouse submission attempted
    # @see PensionBenefitIntakeJob
    #
    # @param claim [Pension::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_uuid [UUID]
    # @param upload [Hash] lighthouse upload data
    #
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

    ##
    # log Sidkiq job completed
    # @see PensionBenefitIntakeJob
    #
    # @param claim [Pension::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_uuid [UUID]
    #
    def track_submission_success(claim, lighthouse_service, user_uuid)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.success")
      Rails.logger.info('Lighthouse::PensionBenefitIntakeJob submission to LH succeeded', {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_uuid:
                        })
    end

    ##
    # log Sidkiq job failed, automatic retry
    # @see PensionBenefitIntakeJob
    #
    # @param claim [Pension::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_uuid [UUID]
    # @param e [Error]
    #
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

    ##
    # log Sidkiq job exhaustion, complete failure after all retries
    # @see PensionBenefitIntakeJob
    #
    # @param msg [Hash] sidekiq exhaustion response
    # @param claim [Pension::SavedClaim]
    #
    def track_submission_exhaustion(msg, claim = nil)
      user_account_uuid = msg['args'].length <= 1 ? nil : msg['args'][1]
      additional_context = {
        form_id: claim&.form_id,
        claim_id: msg['args'].first,
        confirmation_number: claim&.confirmation_number,
        message: msg
      }
      call_location = caller_locations.first

      if claim
        Pensions::NotificationEmail.new(claim).deliver(:error)
        log_silent_failure_avoided(additional_context, user_account_uuid, call_location:)
      else
        log_silent_failure(additional_context, user_account_uuid, call_location:)
      end

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error('Lighthouse::PensionBenefitIntakeJob submission to LH exhausted!',
                         user_uuid: user_account_uuid, **additional_context)
    end

    ##
    # Tracks the failure to send a confirmation email for a claim.
    # @see PensionBenefitIntakeJob
    #
    # @param claim [Pension::SavedClaim]
    # @param lighthouse_service [LighthouseService]
    # @param user_uuid [String]
    # @param e [Exception]
    #
    def track_send_confirmation_email_failure(claim, lighthouse_service, user_uuid, e)
      Rails.logger.warn('Lighthouse::PensionBenefitIntakeJob send_confirmation_email failed', {
                          claim_id: claim&.id,
                          benefits_intake_uuid: lighthouse_service&.uuid,
                          confirmation_number: claim&.confirmation_number,
                          user_uuid:,
                          message: e&.message
                        })
    end

    ##
    # log Sidkiq job cleanup error occurred, this can occur post success or failure
    # @see PensionBenefitIntakeJob
    #
    # @param claim [Pension::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_uuid [UUID]
    # @param e [Error]
    #
    def track_file_cleanup_error(claim, lighthouse_service, user_uuid, e)
      StatsD.increment("#{SUBMISSION_STATS_KEY}.cleanup_failed")
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
