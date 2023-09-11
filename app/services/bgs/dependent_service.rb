# frozen_string_literal: true

module BGS
  class DependentService
    include SentryLogging

    attr_reader :first_name,
                :middle_name,
                :last_name,
                :ssn,
                :birth_date,
                :common_name,
                :email,
                :icn,
                :participant_id,
                :uuid

    def initialize(user)
      @first_name = user.first_name
      @middle_name = user.middle_name
      @last_name = user.last_name
      @ssn = user.ssn
      @uuid = user.uuid
      @birth_date = user.birth_date
      @common_name = user.common_name
      @email = user.email
      @icn = user.icn
      @participant_id = user.participant_id
      @va_profile_email = user.va_profile_email
    end

    def get_dependents
      service.claimant.find_dependents_by_participant_id(participant_id, ssn) || { persons: [] }
    end

    # rubocop:disable Metrics/MethodLength
    def submit_686c_form(claim)
      Rails.logger.info('BGS::DependentService running!', { user_uuid: uuid, saved_claim_id: claim.id, icn: })
      bgs_person = service.people.find_person_by_ptcpnt_id(participant_id) || service.people.find_by_ssn(ssn) # rubocop:disable Rails/DynamicFindBy
      file_number = bgs_person[:file_nbr]
      # BGS's file number is supposed to be an eight or nine-digit string, and
      # our code is built upon the assumption that this is the case. However,
      # we've seen cases where BGS returns a file number with dashes
      # (e.g. XXX-XX-XXXX). In this case specifically, we can simply strip out
      # the dashes and proceed with form submission.
      file_number = file_number.delete('-') if file_number =~ /\A\d{3}-\d{2}-\d{4}\z/
      form_hash_686c = get_form_hash_686c(file_number:)
      # The `validate_*!` calls below will raise errors if we have an invalid
      # file number, or if the file number and SSN don't match. Even if this is
      # the case, we still want to submit a PDF to the veteran's VBMS eFolder.
      # This is because we are currently relying on the presence of a PDF and
      # absence of a BGS-established claim to identify cases where Form 686c-674
      # submission failed.
      VBMS::SubmitDependentsPdfJob.perform_async(
        claim.id,
        form_hash_686c,
        claim.submittable_686?,
        claim.submittable_674?
      )
      if Flipper.enabled?(:dependents_submit_674_independently)
        if claim.submittable_686? || claim.submittable_674?
          # Previously, we would wait until `BGS::Service#create_person`'s call to
          # BGS's `vnp_person_create` endpoint to fail due to an invalid file number
          # or file number / SSN mismatch. Unfortunately, BGS's error response is
          # so verbose that Sentry is unable to capture the portion of the message
          # detailing this specific file number / SSN error, and is therefore unable
          # to distinguish this error from others in our Sentry dashboards. That is
          # why I am deliberately raising these errors here.
          validate_file_number_format!(file_number:)
          validate_file_number_matches_ssn!(file_number:)
          claim.submittable_686? ? BGS::SubmitForm686cJob.perform_async(uuid, @icn, claim.id, form_hash_686c) : BGS::SubmitForm674Job.perform_async(uuid, @icn, claim.id, form_hash_686c) # rubocop:disable Layout/LineLength
          Rails.logger.info('BGS::DependentService succeeded!', { user_uuid: uuid, saved_claim_id: claim.id, icn: })
        end
      else
        if claim.submittable_686? # rubocop:disable Style/IfInsideElse
          # Previously, we would wait until `BGS::Service#create_person`'s call to
          # BGS's `vnp_person_create` endpoint to fail due to an invalid file number
          # or file number / SSN mismatch. Unfortunately, BGS's error response is
          # so verbose that Sentry is unable to capture the portion of the message
          # detailing this specific file number / SSN error, and is therefore unable
          # to distinguish this error from others in our Sentry dashboards. That is
          # why I am deliberately raising these errors here.
          validate_file_number_format!(file_number:)
          validate_file_number_matches_ssn!(file_number:)
          BGS::SubmitForm686cJob.perform_async(uuid, @icn, claim.id, form_hash_686c)
          Rails.logger.info('BGS::DependentService succeeded!', { user_uuid: uuid, saved_claim_id: claim.id, icn: })
        end
      end
    rescue => e
      Rails.logger.error('BGS::DependentService failed!', { user_uuid: uuid, saved_claim_id: claim.id, icn:, error: e.message }) # rubocop:disable Layout/LineLength
      log_exception_to_sentry(e, { icn:, uuid: }, { team: Constants::SENTRY_REPORTING_TEAM })
    end
    # rubocop:enable Metrics/MethodLength

    private

    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    def external_key
      @external_key ||= begin
        key = common_name.presence || email
        key.first(Constants::EXTERNAL_KEY_MAX_LENGTH)
      end
    end

    def get_form_hash_686c(file_number:)
      {
        'veteran_information' => {
          'full_name' => {
            'first' => first_name,
            'middle' => middle_name,
            'last' => last_name
          },
          'common_name' => common_name,
          'va_profile_email' => @va_profile_email,
          'email' => email,
          'participant_id' => participant_id,
          'ssn' => ssn,
          'va_file_number' => file_number,
          'birth_date' => birth_date,
          'uuid' => uuid,
          'icn' => icn
        }
      }
    end

    def validate_file_number_format!(file_number:)
      # We've observed cases where BGS's file numbers are ten or thirteen digits.
      # BGS has indicated that these file numbers are incorrect and that file numbers
      # should be eight or nine digits. I want to log cases like this, so we can
      # tell BGS the kinds of file numbers we are seeing.
      if file_number.length < 8 || file_number.length > 9
        file_number_pattern = file_number.gsub(/[0-9]/, 'X')
        raise Flipper.enabled?(:dependents_submit_674_independently) ? "Aborting Form 686c/674 submission: BGS file_nbr has invalid format! (#{file_number_pattern})" : "Aborting Form 686c submission: BGS file_nbr has invalid format! (#{file_number_pattern})" # rubocop:disable Layout/LineLength
      end
    end

    def validate_file_number_matches_ssn!(file_number:)
      # BGS has indicated that nine-digit file numbers should be equal to the
      # veteran's SSN. I want to log instances where that is not the case, so that
      # we can inform MPI and others of instances where veteran account data is
      # screwed up.
      if file_number.length == 9 && file_number != ssn
        raise Flipper.enabled?(:dependents_submit_674_independently) ? 'Aborting Form 686c/674 submission: VA.gov SSN does not match BGS file_nbr!' : 'Aborting Form 686c submission: VA.gov SSN does not match BGS file_nbr!' # rubocop:disable Layout/LineLength
      end
    end
  end
end
