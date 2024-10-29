# frozen_string_literal: true

require 'vre/monitor'

module VRE
  class Submit1900Job
    include Sidekiq::Job
    include SentryLogging

    STATSD_KEY_PREFIX = 'worker.vre.submit_1900_job'
    RETRY = 14

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      # uncomment below
      # claim_id, encrypted_user = msg['args']
      # claim = SavedClaim.find(claim_id)
      # user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
      monitor = VRE::Monitor.new
      monitor.track_submission_exhaustion(msg)
      # do email here, send to user
      # email = claim.parsed_form['email'] || user['va_profile_email']
      # VANotify::EmailJob.perform_async(
      #   email,
      #   Settings.vanotify.services.va_gov.template_id.form1900_action_needed_email,
      #   {
      #     #get attributes that are needed
      #     'first_name' => claim.parsed_form.dig('veteranInformation', 'fullName', 'first')
      #     'date' => Time.zone.today.strftime('%B %d, %Y')
      #     'confirmation_number' => claim.confirmation_number
      #   }
      # )
    end

    def perform(claim_id, encrypted_user)
      claim = SavedClaim::VeteranReadinessEmploymentClaim.find claim_id
      user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
      claim.send_to_vre(user)
    rescue => e
      Rails.logger.warn("VRE::Submit1900Job failed, retrying...: #{e.message}")
      raise
    end
  end
end
