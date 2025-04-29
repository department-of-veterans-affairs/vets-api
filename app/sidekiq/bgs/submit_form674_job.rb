# frozen_string_literal: true

require 'bgs/form674'

module BGS
  class SubmitForm674Job < Job
    class Invalid674Claim < StandardError; end
    FORM_ID = '686C-674'
    include Sidekiq::Job
    include SentryLogging

    attr_reader :claim, :user, :user_uuid, :saved_claim_id, :vet_info, :icn, :auto674

    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16

    sidekiq_retries_exhausted do |msg, _error|
      user_uuid, icn, saved_claim_id, encrypted_vet_info, encrypted_user_struct_hash, _auto674 = msg['args']
      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      Rails.logger.error("BGS::SubmitForm674Job failed, retries exhausted! Last error: #{msg['error_message']}",
                         { user_uuid:, saved_claim_id:, icn: })

      BGS::SubmitForm674Job.send_backup_submission(encrypted_user_struct_hash, vet_info, saved_claim_id, user_uuid)
    end

    def perform(user_uuid, icn, saved_claim_id, encrypted_vet_info, encrypted_user_struct_hash = nil, auto674 = nil) # rubocop:disable Metrics/ParameterLists
      Rails.logger.info('BGS::SubmitForm674Job running!', { user_uuid:, saved_claim_id:, icn: })
      instance_params(encrypted_vet_info, icn, encrypted_user_struct_hash, user_uuid, saved_claim_id, auto674)

      submit_form

      send_confirmation_email
      Rails.logger.info('BGS::SubmitForm674Job succeeded!', { user_uuid:, saved_claim_id:, icn: })
      InProgressForm.destroy_by(form_id: FORM_ID, user_uuid:)
    rescue => e
      handle_filtered_errors!(e:, encrypted_user_struct_hash:, encrypted_vet_info:)

      Rails.logger.warn('BGS::SubmitForm674Job received error, retrying...',
                        { user_uuid:, saved_claim_id:, icn:, error: e.message, nested_error: e.cause&.message })
      raise
    end

    def handle_filtered_errors!(e:, encrypted_user_struct_hash:, encrypted_vet_info:)
      filter = FILTERED_ERRORS.any? { |filtered| e.message.include?(filtered) || e.cause&.message&.include?(filtered) }
      return unless filter

      Rails.logger.warn('BGS::SubmitForm674Job received error, skipping retries...',
                        { user_uuid:, saved_claim_id:, icn:, error: e.message, nested_error: e.cause&.message })

      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      self.class.send_backup_submission(encrypted_user_struct_hash, vet_info, saved_claim_id, user_uuid)
      raise Sidekiq::JobRetry::Skip
    end

    def instance_params(encrypted_vet_info, icn, encrypted_user_struct_hash, user_uuid, saved_claim_id, auto674) # rubocop:disable Metrics/ParameterLists
      @vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      @user = BGS::SubmitForm674Job.generate_user_struct(encrypted_user_struct_hash, @vet_info, auto674)
      @icn = icn
      @user_uuid = user_uuid
      @saved_claim_id = saved_claim_id
      @claim = SavedClaim::DependencyClaim.find(saved_claim_id)
    end

    def self.generate_user_struct(encrypted_user_struct, vet_info, auto674 = nil)
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
        common_name: info['common_name'],
        auto674:
      )
    end

    def self.send_backup_submission(encrypted_user_struct_hash, vet_info, saved_claim_id, user_uuid)
      user = generate_user_struct(encrypted_user_struct_hash, vet_info)
      Lighthouse::BenefitsIntake::SubmitCentralForm686cJob.perform_async(
        saved_claim_id,
        KmsEncrypted::Box.new.encrypt(vet_info.to_json),
        KmsEncrypted::Box.new.encrypt(user.to_h.to_json)
      )
      InProgressForm.destroy_by(form_id: FORM_ID, user_uuid:)
    rescue => e
      Rails.logger.warn(
        'BGS::SubmitForm674Job backup submission failed...',
        {
          user_uuid:,
          saved_claim_id:,
          error: e.message,
          nested_error: e.cause&.message
        }
      )
      InProgressForm.find_by(form_id: FORM_ID, user_uuid:)&.submission_pending!
    end

    private

    def submit_form
      claim.add_veteran_info(vet_info)

      raise Invalid674Claim unless claim.valid?(:run_686_form_jobs)

      claim_data = normalize_names_and_addresses!(claim.formatted_674_data(vet_info))

      BGS::Form674.new(user, claim).submit(claim_data)
    end

    def send_confirmation_email
      return if user.va_profile_email.blank?

      template_id = Settings.vanotify.services.va_gov.template_id.form686c_confirmation_email

      if Flipper.enabled?(:dependents_separate_confirmation_email)
        template_id = Settings.vanotify.services.va_gov.template_id.form674_only_confirmation_email
        if @claim.submittable_686?
          template_id = Settings.vanotify.services.va_gov.template_id.form686c_674_confirmation_email
        end
      end

      VANotify::ConfirmationEmail.send(
        email_address: user.va_profile_email,
        template_id:,
        first_name: user&.first_name&.upcase,
        user_uuid_and_form_id: "#{user.uuid}_#{FORM_ID}"
      )
    end
  end
end
