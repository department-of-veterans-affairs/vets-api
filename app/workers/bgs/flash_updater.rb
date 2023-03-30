# frozen_string_literal: true

module BGS
  class FlashUpdater
    include Sidekiq::Worker
    include SentryLogging

    def perform(submission_id)
      submission = Form526Submission.find(submission_id)
      ssn = submission.auth_headers['va_eauth_pnid']
      service = bgs_service(ssn).claimant
      flashes = submission.form[Form526Submission::FLASHES]

      flashes.each do |flash_name|
        # NOTE: Assumption that duplicate flashes are ignored when submitted
        service.add_flash(file_number: ssn, flash_name:)
      rescue BGS::ShareError, BGS::PublicError => e
        Raven.tags_context(source: '526EZ-all-claims', submission_id:)
        log_exception_to_sentry(e)
      end

      assigned_flashes = service.find_assigned_flashes(ssn)[:flashes]
      flashes.each do |flash_name|
        assigned_flash = assigned_flashes.find { |af| af[:flash_name].strip == flash_name }
        if assigned_flash.blank?
          Raven.tags_context(source: '526EZ-all-claims', submission_id:)
          e = StandardError.new("Failed to assign '#{flash_name}' to Veteran")
          log_exception_to_sentry(e)
        end
      end
    end

    def bgs_service(ssn)
      # BGS::Services is in the BGS bgs-ext gem, not to be confused with BGS::Service
      BGS::Services.new(
        external_uid: ssn,
        external_key: ssn
      )
    end
  end
end
