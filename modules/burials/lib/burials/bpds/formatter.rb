# frozen_string_literal: true

module Burials
  # Formatter for converting burial form data into BPDS compatible format.
  module BPDS
    # Formatter class for transforming burial claim form data into BPDS-compatible format.
    class Formatter
      # Initializes a new Formatter instance with a parsed burial form.
      #
      # @param parsed_form [Hash] The parsed burial form data to be formatted
      # @return [Formatter] A new instance of the Formatter class
      def initialize(parsed_form)
        @form = parsed_form
      end

      # Formats the burial claim data into a hash structure compatible with the BPDS system.
      #
      # This method transforms the raw claim data into a standardized hash format by calling individual
      # formatting methods for each field. All nil values are removed from the final hash via #compact.
      # @return [Hash] A hash containing the formatted burial claim data
      def format # rubocop:disable Metrics/MethodLength
        {
          'veteranName' => format_veteran_name,
          'veteranSsn' => format_veteran_ssn,
          'fileNumber' => format_file_number,
          'veteranDob' => format_veteran_dob,
          'veteranDateOfDeath' => format_death_date,
          'dateOfBurial' => format_burial_date,
          'claimantName' => format_claimant_name,
          'claimantSsn' => format_claimant_ssn,
          'claimantDateOfBirth' => format_claimant_dob,
          'mailingAddress' => format_mailing_address,
          'preferredPhoneNumber' => format_preferred_phone,
          'preferredEmail' => format_preferred_email,
          'relationship' => format_relationship,
          'periodsOfService' => format_periods_of_service,
          'veteranServedUnderNameOther' => format_previous_names,
          'locationOfBurialOrRemains' => format_burial_location,
          'veteranBuriedInFederalCemetery' => format_federal_cemetery,
          'veteranBuriedInStateVeteransCemetery' => format_state_veterans_cemetery,
          'federalOrStateGovernmentOrEmployerContribute' => format_govt_contributions,
          'employerContributionAmount' => format_contribution_amount,
          'burialTypeAllowanceRequested' => format_burial_allowance_type,
          'veteranDeathLocation' => format_death_location,
          'previousBurialAllowance' => format_previous_allowance,
          'incurredExpensesVeteranBurial' => format_burial_expenses,
          'certifiedUnclaimed' => format_certified_unclaimed,
          'incurExpensesVeteranPlot' => format_plot_expenses,
          'responsibleForTransportation' => format_transportation,
          'fullyDevelopedClaim' => format_fdc,
          'claimantSignature' => format_signature,
          'claimantPrintedName' => format_printed_name,
          'firmOrCorpOrAgencyNameAndAddress' => format_firm_corp_agency,
          'firmOrCorpOrAgencyPosition' => format_firm_position,
          'witnessSignatureOne' => format_witness_signature_one,
          'witnessAddressOne' => format_witness_address_one,
          'witnessSignatureTwo' => format_witness_signature_two,
          'witnessAddressTwo' => format_witness_address_two,
          'alternateSignature' => format_alternate_signature,
          'alternateSignatureDate' => format_alternate_signature_date
        }.compact
      end

      private

      # Formats the veteran's full name.
      # @return [Hash, nil] Hash with first, middle, last name or nil if not present
      def format_veteran_name
        return nil unless @form['veteranFullName']

        {
          'first' => @form['veteranFullName']['first'],
          'middle' => @form['veteranFullName']['middle'],
          'last' => @form['veteranFullName']['last']
        }.compact
      end

      # Formats the veteran's Social Security Number.
      # @return [Hash, nil] Hash with SSN value or nil if not present
      def format_veteran_ssn
        return nil unless @form['veteranSocialSecurityNumber']

        {
          'value' => @form['veteranSocialSecurityNumber']
        }
      end

      # Formats the veteran's VA file number.
      # @return [Hash, nil] Hash with file number value (with leading 'c' removed if applicable) or nil
      def format_file_number
        return nil unless @form['vaFileNumber']

        {
          'value' => extract_va_file_number(@form['vaFileNumber'])
        }
      end

      # Formats the veteran's date of birth.
      # @return [Hash, nil] Hash with month, day, year or nil if not present
      def format_veteran_dob
        return nil unless @form['veteranDateOfBirth']

        parse_date(@form['veteranDateOfBirth'])
      end

      # Formats the veteran's date of death.
      # @return [Hash, nil] Hash with month, day, year or nil if not present
      def format_death_date
        return nil unless @form['deathDate']

        parse_date(@form['deathDate'])
      end

      # Formats the burial date.
      # @return [Hash, nil] Hash with month, day, year or nil if not present
      def format_burial_date
        return nil unless @form['burialDate']

        parse_date(@form['burialDate'])
      end

      # Formats the claimant's full name.
      # @return [Hash, nil] Hash with first, middle, last name or nil if not present
      def format_claimant_name
        return nil unless @form['claimantFullName']

        {
          'first' => @form['claimantFullName']['first'],
          'middle' => @form['claimantFullName']['middle'],
          'last' => @form['claimantFullName']['last']
        }.compact
      end

      # Formats the claimant's Social Security Number.
      # @return [Hash, nil] Hash with SSN value or nil if not present
      def format_claimant_ssn
        return nil unless @form['claimantSocialSecurityNumber']

        {
          'value' => @form['claimantSocialSecurityNumber']
        }
      end

      # Formats the claimant's date of birth.
      # @return [Hash, nil] Hash with month, day, year or nil if not present
      def format_claimant_dob
        return nil unless @form['claimantDateOfBirth']

        parse_date(@form['claimantDateOfBirth'])
      end

      # Formats the claimant's mailing address.
      # @return [Hash, nil] Hash with address components or nil if not present
      def format_mailing_address
        address = @form['claimantAddress']
        return nil unless address

        {
          'numberAndStreet' => address['street'],
          'aptNumber' => address['street2'],
          'city' => address['city'],
          'state' => address['state'],
          'country' => address['country'],
          'zip' => address['postalCode']
        }.compact
      end

      # Formats the claimant's preferred phone number (domestic or international).
      # @return [Hash, nil] Hash with phone number(s) or nil if not present
      def format_preferred_phone
        domestic = @form['claimantPhone']
        international = @form['claimantIntPhone']
        return nil unless domestic || international

        {
          'domestic' => domestic,
          'international' => international
        }.compact
      end

      # Formats the claimant's preferred email address.
      # @return [Hash, nil] Hash with email value or nil if not present
      def format_preferred_email
        return nil unless @form['claimantEmail']

        {
          'value' => @form['claimantEmail']
        }
      end

      # Formats the claimant's relationship to the veteran.
      # @return [Hash, nil] Hash with boolean flags for each relationship type or nil if not present
      def format_relationship
        return nil unless @form['relationshipToVeteran']

        relationship_value = @form['relationshipToVeteran']
        {
          'spouse' => relationship_value == 'spouse',
          'child' => relationship_value == 'child',
          'parent' => relationship_value == 'parent',
          'executor' => relationship_value == 'executor',
          'funeralHome' => relationship_value == 'funeralDirector',
          'relativeOrFriend' => relationship_value == 'otherFamily'
        }
      end

      # Formats the veteran's periods of service (tours of duty).
      # @return [Array<Hash>, nil] Array of service period hashes or nil if not present
      def format_periods_of_service
        tours = @form['toursOfDuty']
        return nil unless tours&.any?

        tours.map do |tour|
          {
            'enteredService' => {
              'date' => parse_date(tour['dateRangeStart']),
              'place' => tour['placeOfEntry']
            },
            'serviceNumber' => {
              'value' => tour['militaryServiceNumber'] || @form['militaryServiceNumber']
            },
            'separatedFromService' => {
              'date' => parse_date(tour['dateRangeEnd']),
              'place' => tour['placeOfSeparation']
            },
            'gradeRankRatingOrgBranch' => {
              'value' => format_service_branch_info(tour)
            }
          }.compact
        end
      end

      # Formats previous names the veteran served under.
      # @return [Hash, nil] Hash with full name and service branch or nil if not present
      def format_previous_names
        previous_names = @form['previousNames']
        return nil unless previous_names&.any?

        previous_names.map do |name|
          full_name = [name['first'], name['middle'], name['last']].compact.join(' ')
          service_info = name['serviceBranch']

          {
            'fullName' => full_name,
            'serviceRendered' => service_info
          }.compact
        end
      end

      # Formats the location of burial or remains.
      # @return [Hash, nil] Hash with boolean flags for location types or nil if not present
      def format_burial_location
        location = @form['finalRestingPlace']
        return nil unless location

        location_type = location['location']
        result = {
          'cemetery' => location_type == 'cemetery',
          'mausoleum' => location_type == 'mausoleum',
          'privateResidence' => location_type == 'privateResidence',
          'other' => location_type == 'other'
        }

        result['otherSpecified'] = location['other'] if location_type == 'other' && location['other']
        result
      end

      # Formats whether the veteran is buried in a federal cemetery.
      # @return [Hash, nil] Hash with yes/no flags and cemetery name or nil if not present
      def format_federal_cemetery
        national_federal = @form['nationalOrFederal']
        cemetery_name = @form['name']

        return nil if national_federal.nil?

        {
          'yes' => national_federal == true,
          'no' => national_federal == false,
          'cemeteryName' => cemetery_name
        }.compact
      end

      # Formats whether the veteran is buried in a state veterans cemetery or tribal trust land.
      # @return [Hash, nil] Hash with location flags, name, and zip code or nil if not present
      def format_state_veterans_cemetery
        cemetery_location = @form['cemeteryLocation']
        cemetery_question = @form['cemetaryLocationQuestion']
        tribal_location = @form['tribalLandLocation']

        return nil unless cemetery_location || tribal_location || cemetery_question

        result = {
          'stateCemetery' => cemetery_question == 'cemetery',
          'tribalTrustLand' => cemetery_question == 'tribalLand',
          'no' => cemetery_question == 'none'
        }

        # Add name and zip from cemetery or tribal location
        if cemetery_location && cemetery_question == 'cemetery'
          result['name'] = cemetery_location['name']
          result['zipCode'] = cemetery_location['zip']
        elsif tribal_location && cemetery_question == 'tribalLand'
          result['name'] = tribal_location['name']
          result['zipCode'] = tribal_location['zip']
        end

        result.compact
      end

      # Formats whether federal/state government or employer contributed to burial expenses.
      # @return [Hash, nil] Hash with yes/no flags or nil if not present
      def format_govt_contributions
        contributions = @form['govtContributions']
        return nil if contributions.nil?

        {
          'yes' => contributions == true,
          'no' => contributions == false
        }
      end

      # Formats the amount of employer contribution to burial expenses.
      # @return [Hash, nil] Hash with contribution amount value or nil if not present
      def format_contribution_amount
        return nil unless @form['amountGovtContribution']

        {
          'value' => @form['amountGovtContribution']
        }
      end

      # Formats the type of burial allowance being requested.
      # @return [Hash, nil] Hash with boolean flags for allowance types or nil if not present
      def format_burial_allowance_type
        allowance = @form['burialAllowanceRequested']
        return nil unless allowance

        {
          'nonServiceConnectedDeath' => allowance['nonService'] == true,
          'serviceConnectedDeath' => allowance['service'] == true,
          'unclaimedRemains' => allowance['unclaimed'] == true
        }
      end

      # Formats the location where the veteran died.
      # @return [Hash] Hash with location type flags and facility information
      def format_death_location # rubocop:disable Metrics/MethodLength
        location = @form['locationOfDeath']
        return nil unless location

        location_type = location['location']
        home_hospice = @form['homeHospiceCare']
        home_hospice_after_discharge = @form['homeHospiceCareAfterDischarge']

        result = {}

        case location_type
        when 'vaMedicalCenter'
          result['vaMedicalCenter'] = true
          add_facility_info(result, @form['vaMedicalCenter'])
        when 'stateVeteransHome'
          result['stateVeteransHome'] = true
          add_facility_info(result, @form['stateVeteransHome'])
        when 'nursingHome'
          result['nursingHomeNotVa'] = true
        when 'nursingHomeUnderVAContract'
          result['nursingHomeUnderVAContract'] = true
        when 'atHome'
          if home_hospice && home_hospice_after_discharge
            result['nursingHomeUnderVAContract'] = true
          else
            result['nursingHomeNotVa'] = true
          end
        when 'other'
          result['other'] = true
          result['otherValueSpecified'] = location['other']
          result['placeOfDeathSpecified'] = location['other']
        end

        result
      end

      # Formats whether the claimant previously received a burial allowance.
      # @return [Hash, nil] Hash with yes/no flags or nil if not present
      def format_previous_allowance
        allowance = @form['previouslyReceivedAllowance']
        return nil if allowance.nil?

        {
          'yes' => allowance == true,
          'no' => allowance == false
        }
      end

      # Formats whether the claimant incurred burial expenses.
      # @return [Hash, nil] Hash with yes/no flags or nil if not present
      def format_burial_expenses
        expenses = @form['burialExpenseResponsibility']
        return nil if expenses.nil?

        {
          'yes' => expenses == true,
          'no' => expenses == false
        }
      end

      # Formats whether the claimant certifies unclaimed remains.
      # @return [Hash, nil] Hash with yes/no flags or nil if not present
      def format_certified_unclaimed
        confirmation = @form['confirmation']
        return nil unless confirmation

        {
          'yes' => confirmation['checkBox'] == true,
          'no' => confirmation['checkBox'] == false
        }
      end

      # Formats whether the claimant incurred plot/interment expenses.
      # @return [Hash, nil] Hash with yes/no flags or nil if not present
      def format_plot_expenses
        plot_expenses = @form['plotExpenseResponsibility']
        return nil if plot_expenses.nil?

        {
          'yes' => plot_expenses == true,
          'no' => plot_expenses == false
        }
      end

      # Formats whether the claimant is responsible for transportation expenses.
      # @return [Hash, nil] Hash with yes/no flags or nil if not present
      def format_transportation
        transportation = @form['transportationExpenses']
        return nil if transportation.nil?

        {
          'yes' => transportation == true,
          'no' => transportation == false
        }
      end

      # Formats whether the claimant chose the Fully Developed Claim (FDC) option.
      # @return [Hash, nil] Hash with FDC chosen/not chosen flags or nil if not present
      def format_fdc
        process_option = @form['processOption']
        return nil if process_option.nil?

        {
          'fdcChosen' => process_option == true,
          'fdcNotChosen' => process_option == false
        }
      end

      # Formats the claimant's signature confirmation.
      # @return [Hash, nil] Hash with signature flags (yes/no/xMark) or nil if not present
      def format_signature
        # Privacy agreement indicates signature consent
        agreement = @form['privacyAgreementAccepted']
        return nil if agreement.nil?

        {
          'yes' => agreement == true,
          'no' => agreement == false,
          'xMark' => false
        }
      end

      # Formats the claimant's printed name.
      # @return [Hash, nil] Hash with claimant's full name or nil if not present
      def format_printed_name
        claimant_name = @form['claimantFullName']
        return nil unless claimant_name

        full_name = [claimant_name['first'], claimant_name['middle'], claimant_name['last']].compact.join(' ')
        {
          'value' => full_name
        }
      end

      # Formats firm, corporation, or agency name and address.
      # @return [Hash, nil] Hash with firm name or nil if not present
      def format_firm_corp_agency
        # These fields don't appear in current form data
        # Placeholder for future firm/corporation information
        firm_name = @form['firmNameAndAddr']
        return nil unless firm_name

        {
          'name' => firm_name
          # Additional fields could be parsed from firmNameAndAddr if needed
        }
      end

      # Formats the position of the firm/corporation/agency representative.
      # @return [Hash, nil] Hash with position value or nil if not present
      def format_firm_position
        position = @form['officialPosition']
        return nil unless position

        {
          'value' => position
        }
      end

      # Formats witness signature one (currently unmapped).
      # @return [Hash] Empty hash as no corresponding form data exists
      def format_witness_signature_one
        # No witness signature data available in current form structure
        {}
      end

      # Formats witness address one (currently unmapped).
      # @return [Hash] Empty hash as no corresponding form data exists
      def format_witness_address_one
        # No witness address data available in current form structure
        {}
      end

      # Formats witness signature two (currently unmapped).
      # @return [Hash] Empty hash as no corresponding form data exists
      def format_witness_signature_two
        # No witness signature data available in current form structure
        {}
      end

      # Formats witness address two (currently unmapped).
      # @return [Hash] Empty hash as no corresponding form data exists
      def format_witness_address_two
        # No witness address data available in current form structure
        {}
      end

      # Formats alternate signature (currently unmapped).
      # @return [Hash] Empty hash as no corresponding form data exists
      def format_alternate_signature
        # No alternate signature data available in current form structure
        {}
      end

      # Formats alternate signature date (currently unmapped).
      # @return [Hash] Empty hash as no corresponding form data exists
      def format_alternate_signature_date
        # No alternate signature date available in current form structure
        {}
      end

      # Helper methods

      # Parses a date string into month, day, and year components.
      # @param date_string [String] Date in YYYY-MM-DD format
      # @return [Hash, nil] Hash with month, day, year or nil if invalid
      def parse_date(date_string)
        return nil unless date_string

        date = DateTime.parse(date_string)
        {
          'month' => date.month.to_s.rjust(2, '0'),
          'day' => date.day.to_s.rjust(2, '0'),
          'year' => date.year.to_s
        }
      rescue ArgumentError, TypeError
        nil
      end

      # Formats service branch information into a comma-separated string.
      # @param tour [Hash] Tour of duty data containing serviceBranch, rank, and unit
      # @return [String, nil] Formatted service info string or nil if no data present
      def format_service_branch_info(tour)
        parts = [
          tour['serviceBranch'],
          tour['rank'],
          tour['unit']
        ].compact

        parts.any? ? parts.join(', ') : nil
      end

      # Adds facility name and location to the result hash.
      # @param result [Hash] Hash to add facility info to (modified in place)
      # @param facility_data [Hash] Facility data containing facilityName and facilityLocation
      # @return [void]
      def add_facility_info(result, facility_data)
        return unless facility_data

        facility_name = facility_data['facilityName']
        facility_location = facility_data['facilityLocation']

        if facility_name && facility_location
          result['placeOfDeathSpecified'] = "#{facility_name}, #{facility_location}"
        elsif facility_name
          result['placeOfDeathSpecified'] = facility_name
        end
      end

      # Extracts VA file number, removing leading 'c' or 'C' if present for numbers >= 10 chars.
      # @param va_file_number [String] VA file number to extract
      # @return [String] Extracted file number with whitespace removed
      def extract_va_file_number(va_file_number)
        return va_file_number if va_file_number.blank?

        cleaned = va_file_number.strip
        cleaned.length >= 10 ? cleaned.sub(/^[Cc]/, '') : cleaned
      end
    end
  end
end
