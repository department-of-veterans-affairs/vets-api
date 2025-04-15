# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/field_mappings/va1010ez'
module PdfFill
  module Forms
    class Va1010ez < FormBase
      FORM_ID = HealthCareApplication::FORM_ID
      OFF = 'Off'

      # Constants used to map data from the vets-json-schema payload to the values expected
      # by the 10-10EZ PDF form. These mappings are necessary for converting form input
      # data into the correct format for PDF generation.

      MARITAL_STATUS = {
        'Married' => 1,
        'Never Married' => 2,
        'Separated' => 3,
        'Widowed' => 4,
        'Divorced' => 5
      }.freeze

      DEPENDENT_RELATIONSHIP = {
        'Son' => 1,
        'Daughter' => 2,
        'Stepson' => 3,
        'Stepdaughter' => 4
      }.freeze

      DISABILITY_STATUS = {
        %w[highDisability lowDisability] => 'YES',
        %w[none] => 'NO'
      }.freeze

      SEX = {
        'M' => 1,
        'F' => 2
      }.freeze

      DISCLOSE_FINANCIAL_INFORMATION = {
        true => 'Yes, I will provide my household financial information' \
                ' for last calendar year. Complete applicable Sections' \
                ' VII and VIII. Sign and date the form in the Assignment' \
                ' of Benefits section.',
        false => 'No, I do not wish to provide financial information' \
                 'in Sections VII through VIII. If I am enrolled, I ' \
                 ' agree to pay applicable VA copayments. Sign and date' \
                 ' the form in the Assignment of Benefits section.'
      }.freeze

      # Exposure values correspond to true for each key in the pdf options
      EXPOSURE_MAP = {
        'exposureToAirPollutants' => 1,
        'exposureToChemicals' => 2,
        'exposureToRadiation' => 3,
        'exposureToShad' => 4,
        'exposureToOccupationalHazards' => 5,
        'exposureToAsbestos' => 5,
        'exposureToMustardGas' => 5,
        'exposureToContaminatedWater' => 6,
        'exposureToWarfareAgents' => 6,
        'exposureToOther' => 7
      }.freeze

      ETHNICITY_MAP = {
        'isAsian' => 1,
        'isAmericanIndianOrAlaskanNative' => 2,
        'isBlackOrAfricanAmerican' => 3,
        'isWhite' => 4,
        'isNativeHawaiianOrOtherPacificIslander' => 5,
        'hasDemographicNoAnswer' => 6
      }.freeze

      # All date fields on the form so we can iterate over them to format them as the pdf form expects
      # The dependent dates are not included in this list
      DATE_FIELDS = %w[
        medicarePartAEffectiveDate
        spouseDateOfBirth
        dateOfMarriage
        lastEntryDate
        lastDischargeDate
        gulfWarStartDate
        gulfWarEndDate
        agentOrangeStartDate
        agentOrangeEndDate
        veteranDateOfBirth
        toxicExposureStartDate
        toxicExposureEndDate
      ].freeze

      # KEY constant maps the `@form_data` keys to their corresponding PDF field identifiers.
      # These mappings are used to associate the form data with the correct PDF form field
      # (specified by a unique key). This ensures the data is placed in the correct field when generating the PDF.
      KEY = PdfFill::Forms::FieldMappings::Va1010ez::KEY

      # Merge Fields - This method orchestrates the calling of all merge helper methods to
      # process and populate @form_data with the necessary values for the PDF.
      def merge_fields(_options = {})
        merge_veteran_info
        merge_spouse_info
        merge_healthcare_info
        merge_dependents
        merge_veteran_service_info
        merge_disclose_financial_info
        merge_date_fields

        @form_data
      end

      private

      # Merge helpers - These methods update @form_data with the required values, data types,
      # or formatted values that the PDF fields expect. Each method processes form data,
      # formats or maps the data appropriately, and assigns the result back to @form_data,
      # ensuring it is in the expected format for PDF generation.

      def merge_veteran_info
        merge_full_name('veteranFullName')
        merge_sex('gender')
        merge_place_of_birth
        merge_ethnicity_choices
        merge_marital_status
        merge_value('isSpanishHispanicLatino', :map_radio_box_value)
        merge_address_street('veteranAddress')
        merge_address_street('veteranHomeAddress')
      end

      def merge_spouse_info
        merge_full_name('spouseFullName')
        merge_spouse_address_phone_number
      end

      def merge_healthcare_info
        merge_value('wantsInitialVaContact', :map_radio_box_value)
        merge_value('isMedicaidEligible', :map_radio_box_value)
        merge_value('isEnrolledMedicarePartA', :map_radio_box_value)
      end

      def merge_veteran_service_info
        merge_exposure
        merge_military_service
        merge_tera
        merge_service_connected_rating
      end

      def merge_full_name(type)
        @form_data[type] = format_full_name(@form_data[type])
      end

      def merge_address_street(address_type)
        return unless @form_data[address_type]

        address = @form_data[address_type]
        @form_data[address_type]['street'] = combine_full_address(
          {
            'street' => address['street'],
            'street2' => address['street2'],
            'street3' => address['street3']
          }
        )
      end

      def merge_sex(type)
        value = SEX[@form_data[type]]
        if value.nil?
          Rails.logger.error('Invalid sex value when filling out 10-10EZ pdf.',
                             { type:, value: @form_data[type] })
        end

        @form_data[type] = value
      end

      def merge_date_fields
        DATE_FIELDS.each do |field|
          merge_value(field, :format_date)
        end
      end

      def merge_marital_status
        @form_data['maritalStatus'] = MARITAL_STATUS[@form_data['maritalStatus']] || OFF
      end

      def merge_place_of_birth
        @form_data['placeOfBirth'] =
          combine_full_address({
                                 'city' => @form_data['cityOfBirth'],
                                 'state' => @form_data['stateOfBirth']
                               })
      end

      def merge_ethnicity_choices
        ETHNICITY_MAP.each do |key, value|
          @form_data[key] = map_value_for_checkbox(@form_data[key], value)
        end
      end

      def merge_service_connected_rating
        @form_data['vaCompensationType'] = DISABILITY_STATUS.find do |keys, _|
          keys.include?(@form_data['vaCompensationType'])
        end&.last
      end

      def merge_exposure
        EXPOSURE_MAP.each do |key, value|
          @form_data[key] = map_value_for_checkbox(@form_data[key], value)
        end
      end

      def merge_spouse_address_phone_number
        spouse_phone = @form_data['spousePhone']
        @form_data['spouseAddress'] = "#{combine_full_address(@form_data['spouseAddress'])} #{spouse_phone}"
      end

      def merge_tera
        merge_value('radiationCleanupEfforts', :map_check_box)
        merge_value('gulfWarService', :map_check_box)
        merge_value('combatOperationService', :map_check_box)
        merge_value('exposedToAgentOrange', :map_check_box)
      end

      def merge_military_service
        merge_value('purpleHeartRecipient', :map_check_box)
        merge_value('isFormerPow', :map_check_box)
        merge_value('postNov111998Combat', :map_check_box)
        merge_value('disabledInLineOfDuty', :map_check_box)
        merge_value('swAsiaCombat', :map_check_box)
      end

      def merge_disclose_financial_info
        @form_data['discloseFinancialInformation'] =
          DISCLOSE_FINANCIAL_INFORMATION[@form_data['discloseFinancialInformation']] || OFF
      end

      def merge_dependents
        merge_value('provideSupportLastYear', :map_radio_box_value)

        return if @form_data['dependents'].blank?

        if @form_data['dependents'].count == 1
          # Format dependent data for pdf field inputs since only one will be rendered
          merge_single_dependent
        else
          # Format dependent data for additional page since when there are more than one dependents
          # we display them all on the additional info section
          merge_multiple_dependents
        end
      end

      def merge_single_dependent
        dependent = @form_data['dependents'].first

        dependent['fullName'] = format_full_name(dependent['fullName'])
        dependent['dateOfBirth'] = format_date(dependent['dateOfBirth'])
        dependent['becameDependent'] = format_date(dependent['becameDependent'])

        dependent['dependentRelation'] = DEPENDENT_RELATIONSHIP[(dependent['dependentRelation'])] || OFF
        dependent['attendedSchoolLastYear'] = map_radio_box_value(dependent['attendedSchoolLastYear'])
        dependent['disabledBefore18'] = map_radio_box_value(dependent['disabledBefore18'])
        dependent['cohabitedLastYear'] = map_radio_box_value(dependent['cohabitedLastYear'])
      end

      def merge_multiple_dependents
        @form_data['dependents'].each do |dependent|
          dependent['fullName'] = format_full_name(dependent['fullName'])
          dependent['dateOfBirth'] = format_date(dependent['dateOfBirth'])
          dependent['becameDependent'] = format_date(dependent['becameDependent'])

          dependent['dependentEducationExpenses'] = format_currency(dependent['dependentEducationExpenses'])
          dependent['grossIncome'] = format_currency(dependent['grossIncome'])
          dependent['netIncome'] = format_currency(dependent['netIncome'])
          dependent['otherIncome'] = format_currency(dependent['otherIncome'])
        end
      end

      def merge_value(type, method_name)
        @form_data[type] = method(method_name).call(@form_data[type])
      end

      # Map helpers - These methods transform input values into the expected format required for PDF fields
      # They **do not modify** the @form_data but return the corresponding mapped value.

      # Converts a boolean input to the corresponding mapped value for checkboxes.
      def map_value_for_checkbox(input, value)
        input == true ? value : OFF
      end

      # Maps a boolean value to an integer for radio button selection (1 for true, 2 for false, or 'OFF' if undefined).
      def map_radio_box_value(value)
        case value
        when true
          1
        when false
          2
        else
          OFF
        end
      end

      # Maps a boolean value to a 'YES' or 'NO' for checkbox fields.
      def map_check_box(value)
        case value
        when true
          'YES'
        when false
          'NO'
        else
          OFF
        end
      end

      # Format helpers - Each method takes an input value and returns a formatted version of it.
      # These methods **do not modify** the @form_data object directly, but instead return the formatted output.

      # Formats a numeric value into a currency string
      def format_currency(value)
        ActiveSupport::NumberHelper.number_to_currency(value)
      end

      # Formats a date string into the format MM/DD/YYYY.
      # If the date is in the "YYYY-MM-XX" format, it converts it to "MM/YYYY".
      def format_date(date_string)
        return if date_string.blank?

        # Handle 1990-08-XX format where the day is not provided
        if date_string.match?(/^\d{4}-\d{2}-XX$/)
          year, month = date_string.split('-')
          return "#{month}/#{year}"
        end

        date = Date.parse(date_string)
        date.strftime('%m/%d/%Y')
      end

      # Formats a full name using components like last, first, middle, and suffix.
      # It returns the name in the format "Last, First, Middle Suffix".
      def format_full_name(full_name)
        return if full_name.blank?

        last = full_name['last']
        first = full_name['first']
        middle = full_name['middle']
        suffix = full_name['suffix']

        name = [last, first].compact.join(', ')
        name += ", #{middle}" if middle&.strip.present?
        name += " #{suffix}" if suffix&.strip.present?
        name
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
