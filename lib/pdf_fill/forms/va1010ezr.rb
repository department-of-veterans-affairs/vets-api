# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/field_mappings/va1010ezr'
require 'pdf_fill/forms/formatters/va1010ez'
require 'pdf_fill/forms/formatters/va1010ezr'
require 'form1010_ezr/service'

module PdfFill
  module Forms
    class Va1010ezr < FormBase
      FORM_ID = Form1010Ezr::Service::FORM_ID
      OFF = 'Off'
      EZ_FORMATTER = PdfFill::Forms::Formatters::Va1010ez
      EZR_FORMATTER = PdfFill::Forms::Formatters::Va1010ezr
      KEY = PdfFill::Forms::FieldMappings::Va1010ezr::KEY

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

      SEX = {
        'F' => 0,
        'M' => 1
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
        @form_data[type] = EZ_FORMATTER.format_full_name(@form_data[type])
      end

      def merge_veteran_info
        merge_full_name('veteranFullName')
        merge_ssn('veteranSocialSecurityNumber')
        merge_sex('gender')
        merge_phone('homePhone')
        merge_phone('mobilePhone')
        merge_marital_status
        merge_address_street('veteranAddress')
        merge_address_street('veteranHomeAddress')
      end

      def merge_ssn(type)
        @form_data[type] = format_ssn(@form_data[type])
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

      def merge_sex(type)
        value = SEX[@form_data[type]]
        if value.nil?
          Rails.logger.error('Invalid sex value when filling out 10-10EZR pdf.',
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
        dependent = @form_data['dependents'].first

        dependent['fullName'] = EZ_FORMATTER.format_full_name(dependent['fullName'])
        dependent['dateOfBirth'] = EZ_FORMATTER.format_date(dependent['dateOfBirth'])
        dependent['becameDependent'] = EZ_FORMATTER.format_date(dependent['becameDependent'])

        dependent['dependentRelation'] = DEPENDENT_RELATIONSHIP[dependent['dependentRelation']] || OFF
        dependent['attendedSchoolLastYear'] = map_select_value(dependent['attendedSchoolLastYear'])
        dependent['disabledBefore18'] = map_select_value(dependent['disabledBefore18'])
        dependent['cohabitedLastYear'] = map_select_value(dependent['cohabitedLastYear'])
      end

      def merge_dependents
        merge_value('provideSupportLastYear', :map_select_value)

        return if @form_data['dependents'].blank?

        merge_single_dependent
      end

      def merge_single_association(type)
        association = @form_data[type].first

        association['fullName'] = EZ_FORMATTER.format_full_name(association['fullName'])
        association['address'] = combine_full_address(association['address'])
        association['primaryPhone'] = format_phone_number(association['primaryPhone'])
      end

      def merge_associations(type)
        return if @form_data[type].blank?

        merge_single_association(type)
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

      # Maps a boolean value to an integer for radion button or checkbox
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

      def format_date(value)
        EZ_FORMATTER.format_date(value)
      end

      def format_ssn(value)
        EZR_FORMATTER.format_ssn(value)
      end

      def format_phone_number(value)
        EZR_FORMATTER.format_phone_number(value)
      end
    end
  end
end
