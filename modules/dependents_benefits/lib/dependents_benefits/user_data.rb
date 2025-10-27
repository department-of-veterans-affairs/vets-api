# frozen_string_literal: true

require 'dependents_benefits/monitor'

module DependentsBenefits
  class UserData
    attr_reader :first_name,
                :middle_name,
                :last_name,
                :ssn,
                :birth_date,
                :common_name,
                :email,
                :va_profile_email,
                :icn,
                :participant_id,
                :uuid,
                :va_file_number

    def initialize(user, claim_data)
      @first_name = user.first_name.presence || claim_data.dig('veteran_information', 'full_name', 'first')
      @middle_name = user.middle_name.presence || claim_data.dig('veteran_information', 'full_name', 'middle')
      @last_name = user.last_name.presence || claim_data.dig('veteran_information', 'full_name', 'last')
      @ssn = user.ssn.presence
      @uuid = user.uuid.presence
      @birth_date = user.birth_date.presence || claim_data.dig('veteran_information', 'birth_date')
      @common_name = user.common_name.presence
      @email = user.email.presence || claim_data.dig('veteran_contact_information', 'email_address')
      @icn = user.icn.presence
      @participant_id = user.participant_id.presence
      @va_profile_email = user.va_profile_email.presence

      @va_file_number = get_file_number || ssn
    rescue => e
      monitor.track_user_data_error('DependentsBenefits::UserData#initialize error',
                                    'user_hash.failure', error: e)
      raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not initialize user data')
    end

    def get_user_json
      full_name = { 'first' => first_name, 'middle' => middle_name, 'last' => last_name }.compact

      veteran_information = {
        'full_name' => full_name,
        'common_name' => common_name,
        'va_profile_email' => va_profile_email,
        'email' => email,
        'participant_id' => participant_id,
        'ssn' => ssn,
        'va_file_number' => va_file_number,
        'birth_date' => birth_date,
        'uuid' => uuid,
        'icn' => icn
      }.compact

      { 'veteran_information' => veteran_information }.to_json
    rescue => e
      monitor.track_user_data_error('DependentsBenefits::UserData#get_user_hash error',
                                    'user_hash.failure', error: e)
      raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not generate user hash')
    end

    private

    def get_file_number
      # include ssn in call to BGS for mocks
      bgs_person = service.people.find_person_by_ptcpnt_id(participant_id, ssn) || service.people.find_by_ssn(ssn) # rubocop:disable Rails/DynamicFindBy
      va_file_number = bgs_person[:file_nbr]
      # BGS's file number is supposed to be an eight or nine-digit string, and
      # our code is built upon the assumption that this is the case. However,
      # we've seen cases where BGS returns a file number with dashes
      # (e.g. XXX-XX-XXXX). In this case specifically, we can simply strip out
      # the dashes and proceed with form submission.
      va_file_number = va_file_number.delete('-') if va_file_number =~ /\A\d{3}-\d{2}-\d{4}\z/

      va_file_number
    rescue
      monitor.track_user_data_warning('DependentsBenefits::UserData#get_file_number error',
                                      'file_number_lookup.failure',
                                      error: 'Could not retrieve file number from BGS')
      nil
    end

    def service
      @service ||= BGS::Services.new(external_uid: icn, external_key:)
    end

    def external_key
      @external_key ||= begin
        key = common_name.presence || email
        key.first(BGS::Constants::EXTERNAL_KEY_MAX_LENGTH)
      end
    end

    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end
  end
end
