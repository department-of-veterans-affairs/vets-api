# frozen_string_literal: true

require 'bgs/form686c'

module BGS
  class SubmitForm686cJob < Job
    class Invalid686cClaim < StandardError; end
    FORM_ID = '686C-674'
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: false

    def perform(user_uuid, saved_claim_id, vet_info)
      user = User.find(user_uuid)
      Rails.logger.info('BGS::SubmitForm686cJob running!', { user_uuid:, saved_claim_id:, icn: user&.icn })
      in_progress_form = InProgressForm.find_by(form_id: FORM_ID, user_uuid:)
      in_progress_copy = in_progress_form_copy(in_progress_form)
      claim_data = valid_claim_data(saved_claim_id, vet_info)
      normalize_names_and_addresses!(claim_data)

      BGS::Form686c.new(user).submit(claim_data)

      # If Form 686c job succeeds, then enqueue 674 job.
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      BGS::SubmitForm674Job.perform_async(user_uuid, saved_claim_id, vet_info) if claim.submittable_674?

      send_confirmation_email(user)

      in_progress_form&.destroy
      Rails.logger.info('BGS::SubmitForm686cJob succeeded!', { user_uuid:, saved_claim_id:, icn: user&.icn })
    rescue => e
      Rails.logger.error('BGS::SubmitForm686cJob failed!', { user_uuid:, saved_claim_id:, icn: user&.icn, error: e.message }) # rubocop:disable Layout/LineLength
      log_message_to_sentry(e, :error, {}, { team: 'vfs-ebenefits' })
      salvage_save_in_progress_form(FORM_ID, user_uuid, in_progress_copy)
      DependentsApplicationFailureMailer.build(user).deliver_now if user.present?
    end

    private

    def valid_claim_data(saved_claim_id, vet_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(vet_info)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim.formatted_686_data(vet_info)
    end

    def send_confirmation_email(user)
      return if user.va_profile_email.blank?

      VANotify::ConfirmationEmail.send(
        email_address: user.va_profile_email,
        template_id: Settings.vanotify.services.va_gov.template_id.form686c_confirmation_email,
        first_name: user&.first_name&.upcase,
        user_uuid_and_form_id: "#{user.uuid}_#{FORM_ID}"
      )
    end
  end
end
