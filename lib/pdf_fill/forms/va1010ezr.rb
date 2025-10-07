# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/field_mappings/va1010ezr'
require 'pdf_fill/forms/formatters/va1010ez'
require 'form1010_ezr/service'

module PdfFill
  module Forms
    class Va1010ezr < FormBase
      FORM_ID = Form1010Ezr::Service::FORM_ID
      OFF = 'Off'
      FORMATTER = PdfFill::Forms::Formatters::Va1010ez
      KEY = PdfFill::Forms::FieldMappings::Va1010ezr::KEY

      DEPENDENT_RELATIONSHIP = {
        'Son' => 3,
        'Daughter' => 2,
        'Stepson' => 1,
        'Stepdaughter' => 0
      }.freeze

      ETHNICITY_MAP = {
        'hasDemographicNoAnswer' => 6,
        'isAmericanIndianOrAlaskanNative' => 2,
        'isAsian' => 1,
        'isBlackOrAfricanAmerican' => 3,
        'isNativeHawaiianOrOtherPacificIslander' => 5,
        'isWhite' => 4
      }.freeze

      # Exposure values correspond to true for each key in the pdf options
      EXPOSURE_MAP = {
        'exposureToAirPollutants' => 1,
        'exposureToAsbestos' => 5,
        'exposureToChemicals' => 2,
        'exposureToContaminatedWater' => 6,
        'exposureToMustardGas' => 5,
        'exposureToOccupationalHazards' => 5,
        'exposureToOther' => 7,
        'exposureToRadiation' => 3,
        'exposureToShad' => 4,
        'exposureToWarfareAgents' => 2
      }.freeze

      MARITAL_STATUS = {
        'Married' => 0,
        'Never Married' => 1,
        'Separated' => 2,
        'Widowed' => 3,
        'Divorced' => 4
      }.freeze

      SEX = {
        'F' => 0,
        'M' => 1
      }.freeze

      # All date fields on the form so we can iterate over them to format them as the pdf form expects
      # The dependent dates are not included in this list
      DATE_FIELDS = %w[
        medicarePartAEffectiveDate
        spouseDateOfBirth
        dateOfMarriage
        gulfWarStartDate
        gulfWarEndDate
        agentOrangeStartDate
        agentOrangeEndDate
        veteranDateOfBirth
        toxicExposureStartDate
        toxicExposureEndDate
      ].freeze

      def merge_fields(_options = {})
        merge_veteran_info
        merge_spouse_info
        merge_healthcare_info
        merge_dependents
        merge_associations('nextOfKins')
        merge_associations('emergencyContacts')
        merge_veteran_service_info
        merge_date_fields

        @form_data
      end

      private

      def merge_full_name(type)
        log_error(type, @form_data[type]) if @form_data[type].nil? && type == 'veteranFullName'

        @form_data[type] = FORMATTER.format_full_name(@form_data[type])
      end

      def merge_veteran_info
        merge_full_name('veteranFullName')
        merge_veteran_date_of_birth('veteranDateOfBirth')
        merge_veteran_ssn('veteranSocialSecurityNumber')
        merge_veteran_sex('gender')
        merge_phone('homePhone')
        merge_phone('mobilePhone')
        merge_marital_status
        merge_address_street('veteranAddress')
        merge_address_street('veteranHomeAddress')
      end

      def merge_veteran_ssn(type)
        log_error(type, @form_data[type]) if @form_data[type].nil?

        @form_data[type] = format_ssn(@form_data[type])
      end

      def merge_veteran_date_of_birth(type)
        log_error(type, @form_data[type]) if @form_data[type].nil?

        @form_data['veteranDateOfBirth'] = format_date(@form_data['veteranDateOfBirth'])
      end

      def merge_phone(type)
        @form_data[type] = format_phone_number(@form_data[type])
      end

      def merge_spouse_info
        merge_full_name('spouseFullName')
        merge_spouse_address_phone_number
      end

      def merge_healthcare_info
        merge_value('isMedicaidEligible', :map_select_value)
        @form_data['isEnrolledMedicarePartA'] = map_select_value(@form_data['isEnrolledMedicarePartA'])
      end

      def merge_veteran_service_info
        merge_exposure
        merge_tera
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

      def merge_veteran_sex(type)
        value = SEX[@form_data[type]]

        log_error(type, @form_data[type]) if value.nil?

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
        merge_value('radiationCleanupEfforts', :map_select_value)
        merge_value('gulfWarService', :map_select_value)
        merge_value('combatOperationService', :map_select_value)
        merge_value('exposedToAgentOrange', :map_select_value)
      end

      def merge_single_dependent
        dependent_copy = @form_data['dependents'][0].deep_dup

        dependent_copy['fullName'] = FORMATTER.format_full_name(dependent_copy['fullName'])
        dependent_copy['dateOfBirth'] = FORMATTER.format_date(dependent_copy['dateOfBirth'])
        dependent_copy['becameDependent'] = FORMATTER.format_date(dependent_copy['becameDependent'])

        dependent_copy['receivedSupportLastYear'] =
          map_select_value(dependent_copy['receivedSupportLastYear'])
        dependent_copy['dependentRelation'] = DEPENDENT_RELATIONSHIP[dependent_copy['dependentRelation']] || OFF
        dependent_copy['attendedSchoolLastYear'] = map_select_value(dependent_copy['attendedSchoolLastYear'])
        dependent_copy['disabledBefore18'] = map_select_value(dependent_copy['disabledBefore18'])
        dependent_copy['cohabitedLastYear'] = map_select_value(dependent_copy['cohabitedLastYear'])

        @form_data['dependents'][0] = dependent_copy
      end

      def merge_multiple_dependents
        @form_data['dependents'] = @form_data['dependents'].map do |dependent|
          dependent_copy = dependent.deep_dup

          dependent_copy['fullName'] = FORMATTER.format_full_name(dependent_copy['fullName'])
          dependent_copy['dateOfBirth'] = FORMATTER.format_date(dependent_copy['dateOfBirth'])
          dependent_copy['becameDependent'] = FORMATTER.format_date(dependent_copy['becameDependent'])

          dependent_copy['dependentEducationExpenses'] = FORMATTER.format_currency(
            dependent_copy['dependentEducationExpenses']
          )
          dependent_copy['receivedSupportLastYear'] = map_select_value(dependent_copy['receivedSupportLastYear'])
          dependent_copy['grossIncome'] = FORMATTER.format_currency(dependent_copy['grossIncome'])
          dependent_copy['netIncome'] = FORMATTER.format_currency(dependent_copy['netIncome'])
          dependent_copy['otherIncome'] = FORMATTER.format_currency(dependent_copy['otherIncome'])

          dependent_copy
        end
      end

      def merge_dependents
        merge_provide_support_last_year

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

      # True if either `provideSupportLastYear` (spouse) or any of dependents `receivedSupportLastYear` is true
      def merge_provide_support_last_year
        if @form_data['dependents'].blank?
          merge_value('provideSupportLastYear', :map_select_value)
          return
        end

        dependent_received_support = @form_data['dependents'].any? do |dependent|
          dependent['receivedSupportLastYear']
        end

        @form_data['provideSupportLastYear'] =
          map_select_value(@form_data['provideSupportLastYear'] || dependent_received_support)
      end

      def merge_associations(type)
        return if @form_data[type].blank?

        @form_data[type] = @form_data[type].map do |association|
          association_copy = association.deep_dup
          association_copy['fullName'] = FORMATTER.format_full_name(association_copy['fullName'])
          association_copy['address'] = combine_full_address(association_copy['address'])
          association_copy['primaryPhone'] = format_phone_number(association_copy['primaryPhone'])

          association_copy
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

      # Maps a boolean value to an integer for radio button or checkbox
      # selection ('YES' for true, 'NO' for false, or 'OFF' if undefined).
      def map_select_value(value)
        case value
        when true
          'YES'
        when false
          'NO'
        else
          OFF
        end
      end

      def log_error(type, _value)
        Rails.logger.error(
          "Invalid #{type} value when filling out 10-10EZR pdf.",
          {
            type:,
            value: @form_data[type]
          }
        )
      end

      def format_date(value)
        FORMATTER.format_date(value)
      end

      def format_ssn(value)
        FORMATTER.format_ssn(value)
      end

      def format_phone_number(value)
        FORMATTER.format_phone_number(value)
      end
    end
  end
end
