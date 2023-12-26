# frozen_string_literal: true

require 'bgs/form686c'

module BGS
  class SubmitForm686cJob < Job
    class Invalid686cClaim < StandardError; end
    FORM_ID = '686C-674'
    include Sidekiq::Job
    include SentryLogging

    attr_reader :claim, :user, :in_progress_copy, :user_uuid, :saved_claim_id, :vet_info

    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |msg, error|
      user_uuid, icn, saved_claim_id, vet_info = msg['args']
      Rails.logger.error('BGS::SubmitForm686cJob failed, retries exhausted!',
                         { user_uuid:, saved_claim_id:, icn:, error: })
      salvage_save_in_progress_form(FORM_ID, user_uuid, in_progress_copy)
      if Flipper.enabled?(:dependents_central_submission)
        user ||= generate_user_struct(vet_info['veteran_information'])
        CentralMail::SubmitCentralForm686cJob.perform_async(saved_claim_id,
                                                            KmsEncrypted::Box.new.encrypt(vet_info.to_json),
                                                            KmsEncrypted::Box.new.encrypt(user.to_h.to_json))
      else
        DependentsApplicationFailureMailer.build(user).deliver_now if user&.email.present? # rubocop:disable Style/IfInsideElse
      end
    end

    def perform(user_uuid, icn, saved_claim_id, vet_info)
      Rails.logger.info('BGS::SubmitForm686cJob running!', { user_uuid:, saved_claim_id:, icn: })

      @vet_info = vet_info
      @user = generate_user_struct
      @user_uuid = user_uuid
      @saved_claim_id = saved_claim_id

      in_progress_form = InProgressForm.find_by(form_id: FORM_ID, user_uuid:)
      @in_progress_copy = in_progress_form_copy(in_progress_form)

      claim_data = normalize_names_and_addresses!(valid_claim_data)

      BGS::Form686c.new(user, claim).submit(claim_data)

      # If Form 686c job succeeds, then enqueue 674 job.
      user_struct_hash = user.to_h
      BGS::SubmitForm674Job.perform_async(user_uuid, icn, saved_claim_id, vet_info, user_struct_hash) if claim.submittable_674? # rubocop:disable Layout/LineLength

      send_confirmation_email
      in_progress_form&.destroy
      Rails.logger.info('BGS::SubmitForm686cJob succeeded!', { user_uuid:, saved_claim_id:, icn: })
    rescue => e
      Rails.logger.warn('BGS::SubmitForm686cJob failed, retrying...',
                        { user_uuid:, saved_claim_id:, icn:, error: e.message })
      log_message_to_sentry(e, :warning, {}, { team: 'vfs-ebenefits' })
      @icn = icn

      raise
    end

    private

    def valid_claim_data
      @claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(vet_info)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim.formatted_686_data(vet_info)
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

    def generate_user_struct
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
  end
end
