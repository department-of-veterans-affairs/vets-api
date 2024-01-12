# frozen_string_literal: true

require 'bgs/form674'

module BGS
  class SubmitForm674EncryptedJob < Job
    class Invalid674Claim < StandardError; end
    FORM_ID = '686C-674'
    include Sidekiq::Job
    include SentryLogging

    attr_reader :claim, :user, :in_progress_copy, :user_uuid, :saved_claim_id, :vet_info

    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |msg, error|
      user_uuid, icn, saved_claim_id, encrypted_vet_info, encrypted_user_struct_hash = msg['args']
      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      Rails.logger.error('BGS::SubmitForm674Job failed, retries exhausted...',
                         { user_uuid:, saved_claim_id:, icn:, error: })
      if Flipper.enabled?(:dependents_central_submission)
        user ||= BGS::SubmitForm674Job.generate_user_struct(encrypted_user_struct_hash, vet_info)
        CentralMail::SubmitCentralForm686cJob.perform_async(saved_claim_id,
                                                            KmsEncrypted::Box.new.encrypt(vet_info.to_json),
                                                            KmsEncrypted::Box.new.encrypt(user.to_h.to_json))
      else
        DependentsApplicationFailureMailer.build(user).deliver_now if user&.email.present? # rubocop:disable Style/IfInsideElse # Temporary for flipper
      end
    end

    def perform(user_uuid, icn, saved_claim_id, encrypted_vet_info, encrypted_user_struct_hash = nil)
      @vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      Rails.logger.info('BGS::SubmitForm674Job running!', { user_uuid:, saved_claim_id:, icn: })

      @user = BGS::SubmitForm674Job.generate_user_struct(encrypted_user_struct_hash, @vet_info)
      @user_uuid = user_uuid
      @saved_claim_id = saved_claim_id

      in_progress_form = InProgressForm.find_by(form_id: FORM_ID, user_uuid:)
      @in_progress_copy = in_progress_form_copy(in_progress_form)

      claim_data = normalize_names_and_addresses!(valid_claim_data)

      BGS::Form674.new(user, claim).submit(claim_data)

      send_confirmation_email
      in_progress_form&.destroy
      Rails.logger.info('BGS::SubmitForm674Job succeeded!', { user_uuid:, saved_claim_id:, icn: })
    rescue => e
      Rails.logger.warn('BGS::SubmitForm674Job received error, retrying...',
                        { user_uuid:, saved_claim_id:, icn:, error: e.message })
      log_message_to_sentry(e, :warning, {}, { team: 'vfs-ebenefits' })
      salvage_save_in_progress_form(FORM_ID, user_uuid, @in_progress_copy) if @in_progress_copy.present?
      raise
    end

    def self.generate_user_struct(encrypted_user_struct, vet_info)
      if encrypted_user_struct.present?
        return OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user_struct)))
      end

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

    private

    def valid_claim_data
      @claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(vet_info)

      raise Invalid674Claim unless claim.valid?(:run_686_form_jobs)

      claim.formatted_674_data(vet_info)
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
