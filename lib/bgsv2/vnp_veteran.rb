# frozen_string_literal: true

require_relative 'service'

module BGSV2
  class VnpVeteran
    include SentryLogging

    def initialize(proc_id:, payload:, user:, claim_type:)
      @user = user
      @proc_id = proc_id
      @payload = payload.with_indifferent_access
      @veteran_info = veteran.formatted_params(@payload)
      @claim_type = claim_type
      @va_file_number = @payload['veteran_information']['va_file_number']
    end

    # rubocop:disable Metrics/MethodLength
    def create
      participant = bgs_service.create_participant(@proc_id, @user.participant_id)
      claim_type_end_product = bgs_service.find_benefit_claim_type_increment(@claim_type)

      # This conditional makes it easier to write specs asserting that
      # log_message_to_sentry is called in #create_person. Though, we may
      # consider removing :warn logs like this from Sentry.
      unless Rails.env.test?
        log_message_to_sentry("#{@proc_id}-#{claim_type_end_product}", :warn, '', { team: 'vfs-ebenefits' })
      end

      address = create_address(participant)
      regional_office_number = get_regional_office(address[:zip_prefix_nbr], address[:cntry_nm], '')
      location_id = get_location_id(regional_office_number)
      create_person(participant)
      bgs_service.create_phone(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      veteran.veteran_response(
        participant,
        address,
        {
          va_file_number: @va_file_number,
          claim_type_end_product:,
          regional_office_number:,
          location_id:,
          net_worth_over_limit_ind: veteran.formatted_boolean(@payload['dependents_application']['household_income'])
        }
      )
    end
    # rubocop:enable Metrics/MethodLength

    private

    def create_person(participant)
      sentry_params = [:error, {}, { team: 'vfs-ebenefits' }]
      if @veteran_info['ssn']&.length != 9
        Rails.logger.info('Malformed SSN! Reassigning to User#ssn.')
        @veteran_info['ssn'] = @user.ssn
      end
      ssn = @veteran_info['ssn']
      if ssn == '********'
        log_message_to_sentry('SSN is redacted!', *sentry_params)
      elsif ssn.present? && ssn.length != 9
        log_message_to_sentry("SSN has #{ssn.length} digits!", *sentry_params)
      end

      person_params = veteran.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      bgs_service.create_person(person_params)
    end

    def create_address(participant)
      address_params = veteran.create_address_params(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      address = bgs_service.create_address(address_params)

      address[:address_type] = 'OVR' if address[:mlty_post_office_type_cd].present?

      if address[:frgn_postal_cd].present?
        address[:foreign_mail_code] = address.delete('frgn_postal_cd')
        address[:address_type] = 'INT'
      end

      address
    end

    def get_regional_office(zip, country, province)
      # find the regional office number closest to the Veteran's zip code
      bgs_service.get_regional_office_by_zip_code(
        zip, country, province, 'CP', @user.ssn
      )
    end

    def get_location_id(regional_office_number)
      # retrieve the list of all regional offices
      # match the regional number to find the corresponding location id
      regional_offices = bgs_service.find_regional_offices
      return '347' if regional_offices.nil? # return default value 347 if regional office is not found

      regional_office = regional_offices.find { |ro| ro[:station_number] == regional_office_number }
      return '347' if regional_office.nil? # return default value 347 if regional office is not found

      regional_office[:lctn_id]
    end

    def veteran
      @veteran ||= BGSDependents::Veteran.new(@proc_id, @user)
    end

    def bgs_service
      BGSV2::Service.new(@user)
    end
  end
end
