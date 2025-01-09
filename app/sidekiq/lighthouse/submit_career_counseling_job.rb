# frozen_string_literal: true

require 'pcpg/monitor'

module Lighthouse
  class SubmitCareerCounselingJob
    include Sidekiq::Job
    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    RETRY = 16

    STATSD_KEY_PREFIX = 'worker.lighthouse.submit_career_counseling_job'

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      begin
        claim = SavedClaim.find(msg['args'].first)
      rescue
        claim = nil
      end

      Lighthouse::SubmitCareerCounselingJob.trigger_failure_events(msg, claim) if Flipper.enabled?(:pcpg_trigger_action_needed_email) # rubocop:disable Layout/LineLength
    end

    def perform(claim_id, user_uuid = nil)
      begin
        @claim = SavedClaim.find(claim_id)
        @claim.send_to_benefits_intake!
        send_confirmation_email(user_uuid)
      rescue => e
        Rails.logger.warn('SubmitCareerCounselingJob failed, retrying...', { error_message: e.message })
        raise
      end
      Rails.logger.info('Successfully submitted form 25-8832', { uuid: user_uuid })
    end

    def send_confirmation_email(user_uuid)
      email = if user_uuid.present? && (found_email = User.find(user_uuid)&.va_profile_email)
                found_email
              else
                @claim.parsed_form.dig('claimantInformation', 'emailAddress')
              end

      if email.blank?
        Rails.logger.info("No email to send confirmation regarding submitted form 25-8832 for uuid: #{user_uuid}")
        return
      end

      VANotify::EmailJob.perform_async(
        email,
        Settings.vanotify.services.va_gov.template_id.career_counseling_confirmation_email,
        {
          'first_name' => @claim.parsed_form.dig('claimantInformation', 'fullName', 'first')&.upcase.presence,
          'date' => Time.zone.today.strftime('%B %d, %Y')
        }
      )
    end

    def self.trigger_failure_events(msg, claim)
      pcpg_monitor = PCPG::Monitor.new
      email = claim.parsed_form.dig('claimantInformation', 'emailAddress')
      pcpg_monitor.track_submission_exhaustion(msg, claim, email)
      claim.send_failure_email(email) if claim.present?
    end
  end
end
