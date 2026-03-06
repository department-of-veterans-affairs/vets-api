# frozen_string_literal: true

module TimeOfNeed
  module MuleSoft
    ##
    # Transforms a parsed form submission into the payload structure
    # expected by the MuleSoft API, which routes to MDW → CaMEO (Salesforce).
    #
    # The form data uses flat frontend field names (camelCase).
    # The payload maps these to the Salesforce object/field structure
    # documented in the TON Field Gap Analysis.
    #
    # @example
    #   claim = TimeOfNeed::SavedClaim.find(123)
    #   builder = TimeOfNeed::MuleSoft::PayloadBuilder.new(claim)
    #   payload = builder.build
    #   # => { "caseDetails" => {...}, "veteran" => {...}, ... }
    #
    class PayloadBuilder
      attr_reader :claim, :form

      ##
      # @param claim [TimeOfNeed::SavedClaim] the saved claim
      def initialize(claim)
        @claim = claim
        @form = claim.parsed_form
      end

      ##
      # Build the complete MuleSoft submission payload
      #
      # @return [Hash] structured payload for MuleSoft API
      def build
        {
          'metadata' => build_metadata,
          'caseDetails' => build_case_details,
          'veteran' => build_veteran,
          'claimant' => build_claimant,
          'personalRepresentative' => build_personal_representative,
          'militaryService' => build_military_service,
          'interment' => build_interment,
          'funeralHome' => build_funeral_home,
          'scheduling' => build_scheduling,
          'attachments' => build_attachments_manifest
        }.compact
      end

      private

      # ----------------------------------------------------------------
      # Metadata
      # ----------------------------------------------------------------
      def build_metadata
        {
          'formId' => TimeOfNeed::FORM_ID,
          'claimId' => claim.id,
          'claimGuid' => claim.guid,
          'submittedAt' => Time.now.utc.iso8601,
          'formStartDate' => claim.form_start_date&.iso8601
        }.compact
      end

      # ----------------------------------------------------------------
      # Case Details (MBMS_Case_Details__c)
      # Maps to: Start Screen fields in CaMEO
      # ----------------------------------------------------------------
      def build_case_details
        {
          # Start screen
          'MBMS_Case_Type__c' => 'Time of Need',
          'MBMS_Origin__c' => 'VA.gov',
          'Received_Date__c' => Time.now.utc.strftime('%Y-%m-%d'),
          'VA_gov_Tracking_Number__c' => claim.guid,
          'MBMS_First_or_Subsequent__c' => currently_buried_first_or_subsequent,

          # Pre-Need
          'hasPreneedDecisionLetter' => form['hasPreneedDecisionLetter'],
          'preneedDecisionLetterNumber' => form['preneedDecisionLetterNumber'],

          # Claimant demographics (stored on Case Details in CaMEO)
          'MBMS_Birth_Sex__c' => map_gender(form['gender']),
          'MBMS_Decedent_Ethnicity__c' => map_ethnicity(form['ethnicity']),
          'MBMS_Decedent_Race__c' => map_races(form['race']),

          # Federal law
          'MBMS_Sexual_Offense_Convicted__c' => map_yes_no_unknown(form['sexualOffense']),
          'MBMS_Capital_Crime_Committed__c' => map_yes_no_unknown(form['capitalCrime']),

          # Emblem of belief
          'MBMS_Emblem__c' => form['selectedEmblem'],

          # Scheduling preferences
          'requestEmblemOfBelief' => form['requestEmblemOfBelief'],

          # Interment details (stored on Case Details)
          'MBMS_Remains_Type__c' => map_burial_type(form['burialType']),
          'MBMS_Burial_Activity_Type__c' => 'Interment',

          # Dependent / eligibility
          'deceasedType' => form['deceasedType'],
          'hasAdultDependentChild' => form['hasAdultDependentChild'],

          # Marital
          'isSpouseOfDeceased' => form['isSpouseOfDeceased']
        }.compact
      end

      # ----------------------------------------------------------------
      # Veteran / Sponsor (Contact)
      # Maps to: Veteran Screen in CaMEO
      # ----------------------------------------------------------------
      def build_veteran
        # If the deceased IS the veteran, use deceased info
        # If the deceased is a spouse/dependent, we need separate veteran info
        if form['deceasedType'] == 'veteran'
          build_veteran_from_deceased
        else
          build_veteran_from_marital_info
        end
      end

      def build_veteran_from_deceased
        {
          'FirstName' => form['deceasedFirstName'],
          'MiddleName' => form['deceasedMiddleName'],
          'LastName' => form['deceasedLastName'],
          'MBMS_Suffix__c' => form['deceasedSuffix'],
          'Maiden_Name__c' => form['deceasedMaidenName'],
          'SSN__c' => form['ssn'],
          'Birthdate' => form['dateOfBirth'],
          'MBMS_Is_Deceased__c' => 'Yes',
          'MBMS_Date_of_Death__c' => form['dateOfDeath'],
          'MBMS_Marital_Status__c' => map_marital_status(form['maritalStatus']),
          'MBMS_Military_Status__c' => determine_military_status,
          'MBMS_Service_Eligibility_Indicator__c' => 'Yes'
        }.compact
      end

      def build_veteran_from_marital_info
        veteran = {
          'MBMS_Service_Eligibility_Indicator__c' => 'Yes'
        }
        # If applicant IS a veteran
        if form['isVeteran'] == 'yes'
          veteran.merge!(
            'FirstName' => form.dig('applicantName', 'first'),
            'LastName' => form.dig('applicantName', 'last'),
            'vaFileNumber' => form['vaFileNumber'],
            'Service_Number__c' => form['militaryServiceNumber']
          )
        end
        veteran.compact
      end

      # ----------------------------------------------------------------
      # Claimant / Decedent (Contact)
      # Maps to: Claimant Screen in CaMEO
      # ----------------------------------------------------------------
      def build_claimant
        {
          'FirstName' => form['deceasedFirstName'],
          'MiddleName' => form['deceasedMiddleName'],
          'LastName' => form['deceasedLastName'],
          'MBMS_Suffix__c' => form['deceasedSuffix'],
          'Maiden_Name__c' => form['deceasedMaidenName'],
          'SSN__c' => form['ssn'],
          'Birthdate' => form['dateOfBirth'],
          'MBMS_Date_of_Death__c' => form['dateOfDeath'],
          'MBMS_Marital_Status__c' => map_marital_status(form['maritalStatus']),
          'Views_Gender__c' => map_gender(form['gender']),
          'MBMS_Service_Area__c' => 'Unknown'
        }.compact
      end

      # ----------------------------------------------------------------
      # Personal Representative (Contact)
      # Maps to: Personal Representative Screen in CaMEO
      # ----------------------------------------------------------------
      def build_personal_representative
        {
          'FirstName' => form.dig('applicantName', 'first'),
          'MiddleName' => form.dig('applicantName', 'middle'),
          'LastName' => form.dig('applicantName', 'last'),
          'MBMS_Suffix__c' => form.dig('applicantName', 'suffix'),
          'Phone' => form['phoneNumber'],
          'Email' => form['emailAddress'],
          'MBMS_Relationship_to_Decedent__c' => map_relationship(form['relationshipToVeteran']),
          'address' => build_address(form['address'])
        }.compact
      end

      # ----------------------------------------------------------------
      # Military Service (MBMS_Military_Service_Info__c)
      # Maps to: Military Service Screen in CaMEO
      # ----------------------------------------------------------------
      def build_military_service
        service_periods = form['servicePeriods']
        return [] if service_periods.blank?

        service_periods.map do |period|
          {
            'Branch_of_Service__c' => period['branchOfService'],
            'MBMS_Military_Rank__c' => period['highestRank'],
            'MBMS_Entered_On_Duty_EOD_Date__c' => period['serviceStartDate'],
            'MBMS_Release_from_Active_Duty_RAD_Date__c' => period['serviceEndDate'],
            'Character_of_Service__c' => map_discharge_character(period['dischargeCharacter'])
          }.compact
        end
      end

      # ----------------------------------------------------------------
      # Interment (MBMS_Case_Details__c interment fields)
      # Maps to: Interment Screen in CaMEO
      # ----------------------------------------------------------------
      def build_interment
        interment = {
          'MBMS_Remains_Type__c' => map_burial_type(form['burialType']),
          'burialLocation' => map_burial_location(form['burialLocation']),
          'containerType' => form['containerType'],
          'MBMS_Emblem__c' => form['selectedEmblem'],
          'desiredCemetery' => form.dig('desiredCemetery', 'label'),
          'desiredCemeteryId' => form.dig('desiredCemetery', 'id'),
          'currentlyBuried' => form['currentlyBuried']
        }.compact

        # Currently buried persons (for subsequent interments)
        if form['currentlyBuriedPersons'].present?
          interment['currentlyBuriedPersons'] = form['currentlyBuriedPersons'].map do |person|
            {
              'firstName' => person.dig('name', 'first'),
              'lastName' => person.dig('name', 'last'),
              'ssn' => person['ssn'],
              'cemeteryNumber' => person['cemeteryNumber']
            }.compact
          end
        end

        interment
      end

      # ----------------------------------------------------------------
      # Funeral Home (Account)
      # Maps to: Funeral Home / Organizations Screen in CaMEO
      # ----------------------------------------------------------------
      def build_funeral_home
        return nil if form['funeralHomeName'].blank?

        {
          'Name' => form['funeralHomeName'],
          'address' => build_address(form['funeralHomeAddress']),
          'contacts' => [
            {
              'FirstName' => form['funeralContactFirstName'],
              'LastName' => form['funeralContactLastName'],
              'Phone' => form['funeralContactPhoneNumber'],
              'Email' => form['funeralContactEmailAddress']
            }.compact
          ]
        }.compact
      end

      # ----------------------------------------------------------------
      # Scheduling Preferences
      # ----------------------------------------------------------------
      def build_scheduling
        {
          'preferredBurialTimes' => selected_checkbox_keys(form['preferredBurialTimes']),
          'preferredBurialDays' => selected_checkbox_keys(form['preferredBurialDays'])
        }.compact
      end

      # ----------------------------------------------------------------
      # Attachments manifest (file GUIDs for association)
      # ----------------------------------------------------------------
      def build_attachments_manifest
        attachments = form['attachments']
        return [] if attachments.blank?

        attachments.map do |att|
          {
            'name' => att['name'],
            'confirmationCode' => att['confirmationCode']
          }.compact
        end
      end

      # ================================================================
      # Value Mapping Helpers
      #
      # Frontend uses simplified camelCase enum values.
      # CaMEO/Salesforce uses specific picklist values.
      # ================================================================

      def map_gender(value)
        {
          'female' => 'Female',
          'male' => 'Male'
        }[value]
      end

      def map_ethnicity(value)
        {
          'hispanic' => 'Hispanic or Latino',
          'notHispanic' => 'Not Hispanic or Latino',
          'unknown' => 'Unknown',
          'preferNoAnswer' => 'Declined to Answer'
        }[value]
      end

      def map_races(race_hash)
        return nil if race_hash.blank?

        race_map = {
          'americanIndian' => 'American Indian or Alaskan Native',
          'asian' => 'Asian',
          'black' => 'Black or African American',
          'hawaiian' => 'Native Hawaiian or other Pacific Islander',
          'white' => 'White',
          'other' => 'Other',
          'preferNoAnswer' => 'Declined to Answer'
        }

        selected = race_hash.select { |_k, v| v == true }.keys
        selected.map { |key| race_map[key] }.compact.join(';')
      end

      def map_marital_status(value)
        {
          'married' => 'Married',
          'divorcedAnnulled' => 'Divorced',
          'separated' => 'Separated',
          'widowed' => 'Widowed',
          'neverMarried' => 'Never Married'
        }[value]
      end

      def map_burial_type(value)
        {
          'casket' => 'Casket',
          'cremains' => 'Cremains',
          'noRemains' => 'No Remains',
          'intactGreen' => 'Intact Green',
          'cremainsGreen' => 'Cremains Green'
        }[value]
      end

      def map_burial_location(value)
        {
          'inGround' => 'In-ground',
          'columbarium' => 'Columbarium',
          'scattered' => 'Scattered',
          'ossuary' => 'Ossuary'
        }[value]
      end

      def map_discharge_character(value)
        {
          'honorable' => 'Honorable',
          'general' => 'General (Under Honorable Conditions)',
          'otherThanHonorable' => 'Other Than Honorable',
          'badConduct' => 'Bad Conduct',
          'dishonorable' => 'Dishonorable',
          'entryLevelSeparation' => 'Entry Level Separation',
          'uncharacterized' => 'Uncharacterized',
          'unknown' => 'Unknown'
        }[value]
      end

      def map_relationship(value)
        {
          'familyMember' => 'Family Member',
          'funeralHomeRep' => 'Funeral Home',
          'personalRepresentative' => 'Personal Representative',
          'other' => 'Other'
        }[value]
      end

      def map_yes_no_unknown(value)
        {
          'yes' => 'Yes',
          'no' => 'No',
          'unknown' => 'Unknown'
        }[value]
      end

      ##
      # Build address sub-structure from form address hash
      #
      # @param addr [Hash] address from form data
      # @return [Hash, nil]
      def build_address(addr)
        return nil if addr.blank?

        {
          'MBMS_Address_Line_One__c' => addr['street'],
          'MBMS_Address_Line_Two__c' => addr['street2'],
          'city' => addr['city'],
          'state' => addr['state'],
          'postalCode' => addr['postalCode'],
          'country' => addr['country'],
          'MBMS_Foreign_Address__c' => foreign_address?(addr)
        }.compact
      end

      def foreign_address?(addr)
        return false if addr.blank?

        country = addr['country']
        country.present? && !%w[US USA United\ States].include?(country)
      end

      ##
      # Determine first/subsequent based on currently buried status
      def currently_buried_first_or_subsequent
        form['currentlyBuried'] == 'yes' ? 'Subsequent' : 'First'
      end

      ##
      # Extract selected keys from a checkbox group hash
      # e.g. { "8-10" => true, "10-12" => false, "none" => true } => ["8-10", "none"]
      def selected_checkbox_keys(hash)
        return nil if hash.blank?

        hash.select { |_k, v| v == true }.keys
      end

      ##
      # Determine military status from service periods
      def determine_military_status
        periods = form['servicePeriods']
        return nil if periods.blank?

        # If any period has no end date, assume active duty
        if periods.any? { |p| p['serviceEndDate'].blank? }
          'Active Duty'
        else
          'Veteran'
        end
      end
    end
  end
end
