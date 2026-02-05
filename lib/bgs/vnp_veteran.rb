# frozen_string_literal: true

require_relative 'service'
require 'bgs/monitor'

module BGS
  class VnpVeteran
    def initialize(proc_id:, payload:, user:, claim_type:, claim_type_end_product: nil)
      @user = user
      @proc_id = proc_id
      @claim_type_end_product = claim_type_end_product
      @payload = payload.with_indifferent_access
      @veteran_info = veteran.formatted_params(@payload)
      @claim_type = claim_type
      @va_file_number = @payload['veteran_information']['va_file_number']
    end

    def create
      participant = bgs_service.create_participant(@proc_id, @user.participant_id)
      if @claim_type_end_product.blank?
        @claim_type_end_product = bgs_service.find_benefit_claim_type_increment(@claim_type)
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
          claim_type_end_product: @claim_type_end_product,
          regional_office_number:,
          location_id:,
          net_worth_over_limit_ind: veteran.formatted_boolean(@payload['dependents_application']['household_income'])
        }
      )
    end

    private

    # Creates BGS person record for participant after validating/fixing SSN
    # @param participant [Hash] BGS participant data with vnp_ptcpnt_id
    # @return [Hash] BGS create_person response
    def create_person(participant)
      fallback_to_user_ssn
      log_ssn_issues

      person_params = veteran.create_person_params(@proc_id, participant[:vnp_ptcpnt_id], @veteran_info)
      bgs_service.create_person(person_params)
    end

    # Replaces invalid veteran SSN with user's SSN as fallback
    # Logs replacement event when veteran_info SSN fails format validation
    # @return [void]
    def fallback_to_user_ssn
      return if ssn_format?(@veteran_info['ssn'])

      monitor.info('Malformed SSN! Reassigning to User#ssn.', 'vnp_veteran_ssn_fix', user_uuid: @user.uuid)
      @veteran_info['ssn'] = @user.ssn
    end

    # Logs SSN data quality issues without stopping execution
    # Detects redacted SSNs (asterisks) and invalid formats for monitoring
    # @return [void]
    def log_ssn_issues
      ssn = @veteran_info['ssn']

      if ssn == '********'
        monitor.error('SSN is redacted!', 'vnp_veteran_ssn_redacted', user_uuid: @user.uuid)
      elsif ssn.present? && !ssn_format?(ssn)
        monitor.error("SSN has #{ssn.length} characters!", 'vnp_veteran_ssn_invalid', user_uuid: @user.uuid)
      end
    end

    # Validates SSN format as exactly 9 digits
    # @param ssn [String, nil] SSN to validate
    # @return [Boolean] true if SSN matches 9-digit format, false otherwise
    def ssn_format?(ssn)
      ssn =~ /\A\d{9}\z/
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
      return '347' if regional_offices.blank? # return default value 347 if regional office is not found

      regional_office = regional_offices.find { |ro| ro[:station_number] == regional_office_number }
      return '347' if regional_office.nil? # return default value 347 if regional office is not found

      regional_office[:lctn_id]
    end

    def veteran
      @veteran ||= BGSDependents::Veteran.new(@proc_id, @user)
    end

    def bgs_service
      BGS::Service.new(@user)
    end

    def monitor
      @monitor ||= BGS::Monitor.new
    end
  end
end
