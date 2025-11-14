# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/forms/field_mappings/va210779'

module PdfFill
  module Forms
    class Va210779 < FormBase
      include FormHelper
      include FormHelper::PhoneNumberFormatting
      KEY = FieldMappings::Va210779::KEY
      LEVEL_OF_CARE = {
        'skilled' => 1,
        'intermediate' => 2
      }.freeze

      def merge_fields(_options = {})
        reformat_vet_info
        reformat_claimant_info
        reformat_nursing_home_info
        reformat_general_info
        @form_data
      end

      def reformat_vet_info
        vet_info = @form_data['veteranInformation']
        return unless vet_info

        vet_info['dateOfBirth'] = split_date(vet_info['dateOfBirth']) if vet_info['dateOfBirth'].present?
        vet_ssn = vet_info.dig('veteranId', 'ssn')
        vet_info['veteranId']['ssn'] = split_ssn(vet_ssn) if vet_ssn.present?
      end

      def reformat_claimant_info
        claimant_info = @form_data['claimantInformation']

        if claimant_info['dateOfBirth'].present?
          claimant_info['dateOfBirth'] =
            split_date(claimant_info['dateOfBirth'])
        end
        claimant_ssn = claimant_info.dig('veteranId', 'ssn')
        claimant_info['veteranId']['ssn'] = split_ssn(claimant_ssn) if claimant_ssn
      end

      def reformat_nursing_home_info
        nh_info = @form_data['nursingHomeInformation']
        nh_info['dateOfBirth'] = split_date(nh_info['dateOfBirth']) if nh_info['dateOfBirth'].present?
        if nh_info['nursingHomeAddress'].present?
          extract_country(nh_info['nursingHomeAddress'])
          nh_info['nursingHomeAddress']['postalCode'] =
            split_postal_code(nh_info['nursingHomeAddress'])
        end
      end

      def reformat_general_info
        gen_info = @form_data['generalInformation']
        gen_info['admissionDate'] = split_date(gen_info['admissionDate'])
        gen_info['medicaidStartDate'] = split_date(gen_info['medicaidStartDate'])
        gen_info['nursingOfficialPhoneNumber'] = expand_phone_number(gen_info['nursingOfficialPhoneNumber'])
        gen_info['signatureDate'] = split_date(gen_info['signatureDate'])
        gen_info['monthlyCosts'] = split_currency_string(gen_info['monthlyCosts'])
        gen_info['medicaidFacility'] = map_select_value(gen_info['medicaidFacility'])
        gen_info['medicaidApplication'] = map_select_value(gen_info['medicaidApplication'])
        gen_info['patientMedicaidCovered'] = map_select_value(gen_info['patientMedicaidCovered'])
        gen_info['certificationLevelOfCare'] = LEVEL_OF_CARE[gen_info['certificationLevelOfCare']]
      end

      def map_select_value(value)
        # the form maps
        # 1 -> yes
        # 2 -> No

        case value
        when true
          1
        when false
          2
        else
          'OFF'
        end
      end
    end
  end
end
