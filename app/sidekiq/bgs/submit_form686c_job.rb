# frozen_string_literal: true

require 'bgs/form686c'

module BGS
  class SubmitForm686cJob < Job
    class Invalid686cClaim < StandardError; end
    FORM_ID = '686C-674'
    include Sidekiq::Job
    include SentryLogging

    attr_reader :claim, :user, :user_uuid, :saved_claim_id, :vet_info, :icn

    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |msg, _error|
      user_uuid, icn, saved_claim_id, encrypted_vet_info = msg['args']
      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      Rails.logger.error("BGS::SubmitForm686cJob failed, retries exhausted! Last error: #{msg['error_message']}",
                         { user_uuid:, saved_claim_id:, icn: })

      BGS::SubmitForm686cJob.send_backup_submission(vet_info, saved_claim_id, user_uuid)
    end

    def perform(user_uuid, icn, saved_claim_id, encrypted_vet_info)
      Rails.logger.info('BGS::SubmitForm686cJob running!', { user_uuid:, saved_claim_id:, icn: })
      instance_params(encrypted_vet_info, icn, user_uuid, saved_claim_id)

      submit_forms(encrypted_vet_info)

      send_confirmation_email
      Rails.logger.info('BGS::SubmitForm686cJob succeeded!', { user_uuid:, saved_claim_id:, icn: })
      InProgressForm.destroy_by(form_id: FORM_ID, user_uuid:) unless claim.submittable_674?
    rescue => e
      handle_filtered_errors!(e:, encrypted_vet_info:)

      Rails.logger.warn('BGS::SubmitForm686cJob received error, retrying...',
                        { user_uuid:, saved_claim_id:, icn:, error: e.message, nested_error: e.cause&.message })
      log_message_to_sentry(e, :warning, {}, { team: 'vfs-ebenefits' })
      raise
    end

    def handle_filtered_errors!(e:, encrypted_vet_info:)
      filter = FILTERED_ERRORS.any? { |filtered| e.message.include?(filtered) || e.cause&.message&.include?(filtered) }
      return unless filter

      Rails.logger.warn('BGS::SubmitForm686cJob received error, skipping retries...',
                        { user_uuid:, saved_claim_id:, icn:, error: e.message, nested_error: e.cause&.message })

      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      self.class.send_backup_submission(vet_info, saved_claim_id, user_uuid)
      raise Sidekiq::JobRetry::Skip
    end

    def instance_params(encrypted_vet_info, icn, user_uuid, saved_claim_id)
      @vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      @user = BGS::SubmitForm686cJob.generate_user_struct(@vet_info)
      @icn = icn
      @user_uuid = user_uuid
      @saved_claim_id = saved_claim_id
      @claim = SavedClaim::DependencyClaim.find(saved_claim_id)
    end

    def self.generate_user_struct(vet_info)
      info = vet_info['veteran_information']
      full_name = info['full_name']
      OpenStruct.new(
        first_name: full_name['first'],
        last_name: full_name['last'],
        middle_name: full_name['middle'],
        ssn: info['ssn'],
        email: info['email'],
        va_profile_email: info['va_profile_email'],
        participant_id: info['participant_id'],
        icn: info['icn'],
        uuid: info['uuid'],
        common_name: info['common_name']
      )
    end

    def self.send_backup_submission(vet_info, saved_claim_id, user_uuid)
      user = generate_user_struct(vet_info)
      CentralMail::SubmitCentralForm686cJob.perform_async(saved_claim_id,
                                                          KmsEncrypted::Box.new.encrypt(vet_info.to_json),
                                                          KmsEncrypted::Box.new.encrypt(user.to_h.to_json))
      InProgressForm.destroy_by(form_id: FORM_ID, user_uuid:)
    rescue => e
      Rails.logger.warn('BGS::SubmitForm686cJob backup submission failed...',
                        { user_uuid:, saved_claim_id:, error: e.message, nested_error: e.cause&.message })
      InProgressForm.find_by(form_id: FORM_ID, user_uuid:)&.submission_pending!
    end

    private

    def submit_forms(encrypted_vet_info)
      claim.add_veteran_info(vet_info)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim_data = normalize_names_and_addresses!(claim.formatted_686_data(vet_info))

      BGS::Form686c.new(user, claim).submit(claim_data)

      # If Form 686c job succeeds, then enqueue 674 job.
      BGS::SubmitForm674Job.perform_async(user_uuid, icn, saved_claim_id, encrypted_vet_info, KmsEncrypted::Box.new.encrypt(user.to_h.to_json)) if claim.submittable_674? # rubocop:disable Layout/LineLength
    end

    def send_confirmation_email
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
