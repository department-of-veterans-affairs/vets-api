# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section IV: Pension Information
    class Section4 < Section
      # Section configuration hash
      KEY = {
        # 4a
        'socialSecurityDisability' => {
          key: 'form1[0].#subform[48].RadioButtonList[2]'
        },
        # 4b
        'medicalCondition' => {
          key: 'form1[0].#subform[48].RadioButtonList[3]'
        },
        # 4c
        'nursingHome' => {
          key: 'form1[0].#subform[48].RadioButtonList[4]'
        },
        # 4d
        'medicaidStatus' => {
          key: 'form1[0].#subform[48].RadioButtonList[5]'
        },
        # 4e
        'specialMonthlyPension' => {
          key: 'form1[0].#subform[48].RadioButtonList[6]'
        },
        # 4f
        'vaTreatmentHistory' => {
          key: 'form1[0].#subform[49].RadioButtonList[7]'
        },
        'vaMedicalCenters' => {
          item_label: 'VA medical center',
          limit: 1,
          first_key: 'medicalCenter',
          'medicalCenter' => {
            limit: 33,
            question_num: 4,
            question_suffix: 'F',
            question_label: 'Specify VA Facility',
            question_text: 'Specify VA Facility',
            key: 'form1[0].#subform[49].Facility[0]'
          }
        },
        # 4g
        'federalTreatmentHistory' => {
          key: 'form1[0].#subform[49].RadioButtonList[8]'
        },
        'federalMedicalCenters' => {
          item_label: 'Federal medical facility',
          limit: 1,
          first_key: 'medicalCenter',
          'medicalCenter' => {
            limit: 44,
            question_num: 4,
            question_suffix: 'G',
            question_label: 'Specify Federal Facility',
            question_text: 'Specify Federal Facility',
            key: 'form1[0].#subform[49].Facility[1]'
          }
        }
      }.freeze

      ##
      # Expand the form data for pension information.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      # Note: This method modifies `form_data`
      #
      def expand(form_data)
        form_data['nursingHome'] = to_radio_yes_no(form_data['nursingHome'])
        form_data['medicaidStatus'] = to_radio_yes_no(
          form_data['medicaidStatus'] || form_data['medicaidCoverage']
        )
        form_data['specialMonthlyPension'] = to_radio_yes_no(form_data['specialMonthlyPension'])
        form_data['medicalCondition'] = to_radio_yes_no(form_data['medicalCondition'])
        form_data['socialSecurityDisability'] = to_radio_yes_no(
          form_data['socialSecurityDisability'] || form_data['isOver65']
        )

        # If "YES," skip question 4B
        form_data['medicalCondition'] = nil if form_data['socialSecurityDisability'].zero?

        # If "NO," skip question 4D
        form_data['medicaidStatus'] = nil if form_data['nursingHome'] == 1

        form_data['vaTreatmentHistory'] = to_radio_yes_no(form_data['vaTreatmentHistory'])
        form_data['federalTreatmentHistory'] = to_radio_yes_no(form_data['federalTreatmentHistory'])
      end
    end
  end
end
