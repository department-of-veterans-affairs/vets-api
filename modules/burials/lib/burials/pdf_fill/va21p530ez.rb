# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

require_relative 'sections/section_01'
require_relative 'sections/section_02'
require_relative 'sections/section_03'
require_relative 'sections/section_04'
require_relative 'sections/section_05'
require_relative 'sections/section_06'
require_relative 'sections/section_07'

module Burials
  module PdfFill
    # Forms module
    module Forms
      # Burial 21P-530EZ PDF Filler class
      class Va21p530ez < ::PdfFill::Forms::FormBase
        include ::PdfFill::Forms::FormHelper
        include Helpers

        # The ID of the form being processed
        FORM_ID = '21P-530EZ'

        # An external iterator used in data processing
        ITERATOR = ::PdfFill::HashConverter::ITERATOR

        # The path to the PDF template for the form
        TEMPLATE = Burials::PDF_PATH

        # Starting page number for overflow pages
        START_PAGE = 10

        # Default label column width (points) for redesigned extras in this form
        DEFAULT_LABEL_WIDTH = 130

        # Map question numbers to descriptive titles for overflow attachments
        QUESTION_KEY = [
          { question_number: '1', question_text: "Deceased Veteran's Name" },
          { question_number: '2', question_text: "Deceased Veteran's Social Security Number" },
          { question_number: '3', question_text: 'VA File Number' },
          { question_number: '4', question_text: "Veteran's Date of Birth" },
          { question_number: '5', question_text: "Veteran's Date of Death" },
          { question_number: '6', question_text: "Veteran's Date of Burial" },
          { question_number: '7', question_text: "Claimant's Name" },
          { question_number: '8', question_text: "Claimant's Social Security Number" },
          { question_number: '9', question_text: "Claimant's Date of Birth" },
          { question_number: '10', question_text: "Claimant's Address" },
          { question_number: '11', question_text: "Claimant's International Phone Number" },
          { question_number: '12', question_text: 'E-Mail Address' },
          { question_number: '13', question_text: 'Relationship to Veteran' },
          { question_number: '14', question_text: 'Military Service Information' },
          { question_number: '15', question_text: 'Other Names Veteran Served Under' },
          { question_number: '16', question_text: 'Place of Burial Plot, Interment Site, or Final Resting Place' },
          { question_number: '17', question_text: 'National or Federal Cemetery' },
          { question_number: '18', question_text: 'State Cemetery or Tribal Trust Land' },
          { question_number: '19', question_text: 'Government or Employer Contribution' },
          { question_number: '20', question_text: "Where Did the Veteran's Death Occur" },
          { question_number: '21', question_text: 'Burial Allowance Requested' },
          { question_number: '22', question_text: 'Previously Received Allowance' },
          { question_number: '23', question_text: 'Burial Expense Responsibility' },
          { question_number: '24', question_text: 'Plot/Interment Expense Responsibility' },
          { question_number: '25', question_text: 'Claimant Signature' },
          { question_number: '26', question_text: 'Firm, Corporation, or State Agency Information' }
        ].freeze

        # V2-style sections grouping question numbers for overflow pages
        SECTIONS = [
          { label: 'Section I: Deceased Veteran\'s Name', question_nums: ['1'] },
          { label: 'Section II: Deceased Veteran\'s Social Security Number', question_nums: ['2'] },
          { label: 'Section III: VA File Number', question_nums: ['3'] },
          { label: 'Section IV: Veteran\'s Date of Birth', question_nums: ['4'] },
          { label: 'Section V: Veteran\'s Date of Death', question_nums: ['5'] },
          { label: 'Section VI: Veteran\'s Date of Burial', question_nums: ['6'] },
          { label: 'Section VII: Claimant\'s Identification Information', question_nums: %w[7 8 9] },
          { label: 'Section VIII: Claimant\'s Contact Information', question_nums: %w[10 11 12] },
          { label: 'Section IX: Relationship to Veteran', question_nums: ['13'] },
          { label: 'Section X: Military Service Information', question_nums: %w[14 15] },
          { label: 'Section XI: Burial Information', question_nums: %w[16 17 18] },
          { label: 'Section XII: Government Contributions and Death Location', question_nums: %w[19 20] },
          { label: 'Section XIII: Burial Allowance and Expenses', question_nums: %w[21 22 23 24] },
          { label: 'Section XIV: Signatures and Certifications', question_nums: %w[25 26] }
        ].freeze

        # A mapping of care facilities to their labels
        PLACE_OF_DEATH_KEY = {
          'vaMedicalCenter' => 'VA MEDICAL CENTER',
          'stateVeteransHome' => 'STATE VETERANS HOME',
          'nursingHome' => 'NURSING HOME UNDER VA CONTRACT'
        }.freeze

        # Mapping of the filled out form into JSON
        key = {}

        # The list of section classes for form expansion and key building
        SECTION_CLASSES = [Section1, Section2, Section3, Section4, Section5, Section6, Section7].freeze

        SECTION_CLASSES.each { |section| key.merge!(section::KEY) }

        # form configuration hash
        KEY = key.freeze

        ##
        # Expands tours of duty by formatting a few fields
        #
        # @param tours_of_duty [Array<Hash>]
        #
        # @return [Hash]
        def expand_tours_of_duty(tours_of_duty)
          return if tours_of_duty.blank?

          tours_of_duty.each do |tour_of_duty|
            expand_date_range(tour_of_duty, 'dateRange')
            tour_of_duty['rank'] = combine_hash(tour_of_duty, %w[serviceBranch rank unit], ', ')
            tour_of_duty['militaryServiceNumber'] = @form_data['militaryServiceNumber']
          end
        end

        ##
        # Converts the location of death by formatting facility details and adjusting specific location values
        #
        # @return [Hash]
        def convert_location_of_death
          location_of_death = @form_data['locationOfDeath']
          return if location_of_death.blank?

          home_hospice_care = @form_data['homeHospiceCare']
          home_hospice_care_after_discharge = @form_data['homeHospiceCareAfterDischarge']

          location = location_of_death['location']
          options = @form_data[location]
          if options.present? && location != 'other'
            location_of_death['placeAndLocation'] = "#{options['facilityName']} - #{options['facilityLocation']}"
          end

          @form_data.delete(location)

          if location == 'atHome' && home_hospice_care && home_hospice_care_after_discharge
            location_of_death['location'] = 'nursingHomePaid'
          elsif location == 'atHome' && !(home_hospice_care && home_hospice_care_after_discharge)
            location_of_death['location'] = 'nursingHomeUnpaid'
          end

          expand_checkbox_as_hash(@form_data['locationOfDeath'], 'location')
        end

        ##
        # Expands the burial allowance request by ensuring values are formatted as 'On' or nil
        #
        # @return [void]
        def expand_burial_allowance
          @form_data['hasPreviouslyReceivedAllowance'] = select_radio(@form_data['previouslyReceivedAllowance'])
          burial_allowance = @form_data['burialAllowanceRequested']
          return if burial_allowance.blank?

          burial_allowance.each do |key, value|
            burial_allowance[key] = value.present? ? 'On' : nil
          end

          @form_data['burialAllowanceRequested'] = {
            'checkbox' => burial_allowance
          }
        end

        ##
        # Expands cemetery location details by extracting relevant information
        #
        # @return [void]
        def expand_cemetery_location
          cemetery_location = @form_data['cemeteryLocation']
          cemetery_location_question = @form_data['cemetaryLocationQuestion']
          return unless cemetery_location.present? && cemetery_location_question == 'cemetery'

          @form_data['stateCemeteryOrTribalTrustName'] = cemetery_location['name'] if cemetery_location['name'].present?
          @form_data['stateCemeteryOrTribalTrustZip'] = cemetery_location['zip'] if cemetery_location['zip'].present?
        end

        ##
        # Expands tribal land location details by extracting relevant information
        #
        # @return [void]
        def expand_tribal_land_location
          cemetery_location = @form_data['tribalLandLocation']
          cemetery_location_question = @form_data['cemetaryLocationQuestion']
          return unless cemetery_location.present? && cemetery_location_question == 'tribalLand'

          @form_data['stateCemeteryOrTribalTrustName'] = cemetery_location['name'] if cemetery_location['name'].present?
          @form_data['stateCemeteryOrTribalTrustZip'] = cemetery_location['zip'] if cemetery_location['zip'].present?
        end

        ##
        # Extracts and normalizes the VA file number
        #
        # VA file number can be up to 10 digits long; An optional leading 'c' or 'C' followed by
        # 7-9 digits. The file number field on the 4142 form has space for 9 characters so trim the
        # potential leading 'c' to ensure the file number will fit into the form without overflow.
        #
        # @param va_file_number [String, nil]
        #
        # @return [String, nil]
        def extract_va_file_number(va_file_number)
          return va_file_number if va_file_number.blank? || va_file_number.length < 10

          va_file_number.sub(/^[Cc]/, '')
        end

        ##
        # Expands the 'confirmation' field in the form data
        #
        # @return [void]
        def expand_confirmation_question
          if @form_data['confirmation'].present?
            confirmation = @form_data['confirmation']
            @form_data['hasConfirmation'] = select_radio(confirmation['checkBox'])
          end
        end

        ##
        # Expands the 'cemetaryLocationQuestion' to other form_data fields
        #
        # @return [void]
        def expand_location_question
          cemetery_location = @form_data['cemetaryLocationQuestion']
          @form_data['cemetaryLocationQuestionCemetery'] = select_checkbox(cemetery_location == 'cemetery')
          @form_data['cemetaryLocationQuestionTribal'] = select_checkbox(cemetery_location == 'tribalLand')
          @form_data['cemetaryLocationQuestionNone'] = select_checkbox(cemetery_location == 'none')
        end

        ##
        # Combines the previous names and their corresponding service branches into a formatted string
        #
        # @param previous_names [Array<Hash>]
        #
        # @return [String, nil]
        def combine_previous_names_and_service(previous_names)
          return if previous_names.blank?

          previous_names.map do |previous_name|
            "#{combine_full_name(previous_name)} (#{previous_name['serviceBranch']})"
          end.join('; ')
        end

        ##
        # Adjusts the spacing of the 'amountGovtContribution' value by right-justifying it
        #
        # @return [void, nil]
        def format_currency_spacing
          return if @form_data['amountGovtContribution'].blank?

          @form_data['amountGovtContribution'] = @form_data['amountGovtContribution'].rjust(5)
        end

        ##
        # Sets the 'cemeteryLocationQuestion' field to 'none' if the 'nationalOrFederal' field is present and truthy.
        #
        # @return [void, nil]
        def set_state_to_no_if_national
          national = @form_data['nationalOrFederal']
          @form_data['cemetaryLocationQuestion'] = 'none' if national
        end

        ##
        # The crux of the class, this method merges all the data that has been converted into @form_data
        #
        # @param _options [Hash]
        #
        # @return [Hash]
        # rubocop:disable Metrics/MethodLength
        def merge_fields(_options = {})
          expand_signature(@form_data['claimantFullName'])
          %w[veteranFullName claimantFullName].each do |attr|
            extract_middle_i(@form_data, attr)
          end

          %w[veteranDateOfBirth deathDate burialDate claimantDateOfBirth].each do |attr|
            @form_data[attr] = split_date(@form_data[attr])
          end

          ssn = @form_data['veteranSocialSecurityNumber']
          ['', '2', '3'].each do |suffix|
            @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
          end

          @form_data['claimantSocialSecurityNumber'] = split_ssn(@form_data['claimantSocialSecurityNumber'])

          relationship_to_veteran = @form_data['relationshipToVeteran']
          @form_data['relationshipToVeteran'] = {
            'spouse' => select_checkbox(relationship_to_veteran == 'spouse'),
            'child' => select_checkbox(relationship_to_veteran == 'child'),
            'executor' => select_checkbox(relationship_to_veteran == 'executor'),
            'parent' => select_checkbox(relationship_to_veteran == 'parent'),
            'funeralDirector' => select_checkbox(relationship_to_veteran == 'funeralDirector'),
            'otherFamily' => select_checkbox(relationship_to_veteran == 'otherFamily')
          }

          # special case for transportation being the only option selected.
          final_resting_place = @form_data.dig('finalRestingPlace', 'location')
          if final_resting_place.present?
            @form_data['finalRestingPlace']['location'] = {
              'cemetery' => select_checkbox(final_resting_place == 'cemetery'),
              'privateResidence' => select_checkbox(final_resting_place == 'privateResidence'),
              'mausoleum' => select_checkbox(final_resting_place == 'mausoleum'),
              'other' => select_checkbox(final_resting_place == 'other')
            }
          end

          expand_cemetery_location
          expand_tribal_land_location

          @form_data['hasNationalOrFederal'] = select_radio(@form_data['nationalOrFederal'])

          # special case: the UI only has a 'yes' checkbox, so the PDF 'noTransportation' checkbox can never be true.
          @form_data['hasTransportation'] = select_radio(@form_data['transportationExpenses'])

          expand_confirmation_question
          set_state_to_no_if_national
          expand_location_question

          split_phone(@form_data, 'claimantPhone')

          split_postal_code(@form_data)

          expand_tours_of_duty(@form_data['toursOfDuty'])

          @form_data['previousNames'] = combine_previous_names_and_service(@form_data['previousNames'])

          @form_data['vaFileNumber'] = extract_va_file_number(@form_data['vaFileNumber'])

          expand_burial_allowance

          convert_location_of_death

          @form_data['hasGovtContributions'] = select_radio(@form_data['govtContributions'])

          format_currency_spacing

          # These are boolean values that are set up as checkboxes in the PDF
          # instead of radio buttons, so we need to process them differently
          %w[
            burialExpenseResponsibility
            plotExpenseResponsibility
            processOption
          ].each do |attr|
            expand_checkbox_in_place(@form_data, attr)
          end

          SECTION_CLASSES.each { |section| section.new.expand(@form_data) }

          @form_data
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
