# frozen_string_literal: true

require 'bgs/form674'
require 'dependents/monitor'
require 'vets/shared_logging'

module BGS
  class SubmitForm674V2Job < Job
    class Invalid674Claim < StandardError; end
    FORM_ID = '686C-674-V2'
    include Sidekiq::Job
    include Vets::SharedLogging

    attr_reader :claim, :user, :user_uuid, :saved_claim_id, :vet_info, :icn

    STATS_KEY = 'worker.submit_674_bgs'

    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16

    sidekiq_retries_exhausted do |msg, _error|
      user_uuid, saved_claim_id, encrypted_vet_info, encrypted_user_struct_hash = msg['args']
      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      monitor = ::Dependents::Monitor.new(saved_claim_id)
      monitor.track_event('error',
                          "BGS::SubmitForm674Job failed, retries exhausted! Last error: #{msg['error_message']}",
                          'worker.submit_674_bgs.exhaustion')
      # in some instances, bgs will throw an error with language containing `FABusnsTranRule`
      # this has been researched and documented here: https://github.com/department-of-veterans-affairs/va.gov-team/issues/128972
      # there is nothing at the moment the user can do to prevent this error as it is an rbps related trigger
      # the backup path is the correct path for this bug so that the application can be reviewed manually
      BGS::SubmitForm674V2Job.send_backup_submission(encrypted_user_struct_hash, vet_info, saved_claim_id, user_uuid)
    rescue => e
      monitor = ::Dependents::Monitor.new
      monitor.track_event('error', 'BGS::SubmitForm674Job retries exhausted failed...',
                          'worker.submit_674_bgs.retry_exhaustion_failure',
                          { error: e.message, nested_error: e.cause&.message, last_error: msg['error_message'] })
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      email = vet_info&.dig('veteran_information', 'va_profile_email')
      if email.present?
        claim.send_failure_email(email)
      else
        monitor.log_silent_failure(
          monitor.default_payload.merge({ error: e }),
          call_location: caller_locations.first
        )
      end
    end

    def perform(user_uuid, saved_claim_id, encrypted_vet_info, encrypted_user_struct_hash = nil)
      @monitor = init_monitor(saved_claim_id)
      @monitor.track_event('info', 'BGS::SubmitForm674Job running!', "#{STATS_KEY}.begin")
      instance_params(encrypted_vet_info, user_uuid, saved_claim_id, encrypted_user_struct_hash)

      submit_form

      send_confirmation_email
      @monitor.track_event('info', 'BGS::SubmitForm674Job succeeded!', "#{STATS_KEY}.success")

      InProgressForm.destroy_by(form_id: FORM_ID, user_uuid:)
    rescue => e
      handle_filtered_errors!(e:, encrypted_user_struct_hash:, encrypted_vet_info:)

      @monitor.track_event('warn', 'BGS::SubmitForm674Job received error, retrying...', "#{STATS_KEY}.failure",
                           { error: e.message, nested_error: e.cause&.message })
      raise
    end

    def handle_filtered_errors!(e:, encrypted_user_struct_hash:, encrypted_vet_info:)
      filter = FILTERED_ERRORS.any? { |filtered| e.message.include?(filtered) || e.cause&.message&.include?(filtered) }
      return unless filter

      @monitor.track_event('warn', 'BGS::SubmitForm674Job received error, skipping retries...',
                           "#{STATS_KEY}.skip_retries", { error: e.message, nested_error: e.cause&.message })

      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      self.class.send_backup_submission(encrypted_user_struct_hash, vet_info, saved_claim_id, user_uuid)
      raise Sidekiq::JobRetry::Skip
    end

    def instance_params(encrypted_vet_info, user_uuid, saved_claim_id, encrypted_user_struct_hash)
      @vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      @user = BGS::SubmitForm674V2Job.generate_user_struct(encrypted_user_struct_hash, @vet_info)
      @icn = @user.icn
      @user_uuid = user_uuid
      @saved_claim_id = saved_claim_id
      @claim = SavedClaim::DependencyClaim.find(saved_claim_id)
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

    def self.send_backup_submission(encrypted_user_struct_hash, vet_info, saved_claim_id, user_uuid)
      user = generate_user_struct(encrypted_user_struct_hash, vet_info)
      Lighthouse::BenefitsIntake::SubmitCentralForm686cV2Job.perform_async(
        saved_claim_id,
        KmsEncrypted::Box.new.encrypt(vet_info.to_json),
        KmsEncrypted::Box.new.encrypt(user.to_h.to_json)
      )
      InProgressForm.destroy_by(form_id: FORM_ID, user_uuid:)
    rescue => e
      monitor = Dependents::Monitor.new(saved_claim_id)
      monitor.track_event('error', 'BGS::SubmitForm674Job backup submission failed...',
                          "#{STATS_KEY}.backup_failure", { error: e.message, nested_error: e.cause&.message })
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
      claim.send_received_email(user)
    end

    def init_monitor(saved_claim_id)
      @monitor ||= ::Dependents::Monitor.new(saved_claim_id)
    end
  end
end
