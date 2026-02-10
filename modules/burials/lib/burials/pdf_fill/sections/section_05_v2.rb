# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section V: Burial Allowance Information
    class Section5V2 < Section
      # rubocop:disable Layout/LineLength
      # Section configuration hash
      KEY = {
        # 26A
        'burialAllowanceRequested' => {
          'checkbox' => {
            'nonService' => {
              key: 'form1[0].#subform[83].Non-Service-Connected[0]'
            },
            'service' => {
              key: 'form1[0].#subform[83].Service-Connected[0]'
            },
            'unclaimed' => {
              key: 'form1[0].#subform[83].UnclaimedRemains[0]'
            }
          }
        },
        # 26B
        'locationOfDeath' => {
          key: 'form1[0].#subform[95].RadioButtonList[4]'
        },
        # 26C
        'placeAndLocation' => {
          key: 'form1[0].#subform[95].Place_Of_Death[0]',
          limit: 42,
          question_num: 26,
          question_suffix: 'B',
          question_label: "Please Provide Veteran's Specific Place Of Death Including The Name And Location Of The Nursing Home, Va Medical Center Or State Veteran Facility.",
          question_text: "PLEASE PROVIDE VETERAN'S SPECIFIC PLACE OF DEATH INCLUDING THE NAME AND LOCATION OF THE NURSING HOME, VA MEDICAL CENTER OR STATE VETERAN FACILITY."
        },
        # 27A
        'deathUnderVaCoveredHomeHospiceCare' => {
          key: 'form1[0].#subform[95].RadioButtonList[14]'
        },
        # 27B
        'veteranTransferredToVaCoveredHomeHospiceCare' => {
          key: 'form1[0].#subform[95].RadioButtonList[13]'
        },
        # 28
        'hasPreviouslyReceivedAllowance' => {
          key: 'form1[0].#subform[83].PreviousAllowance[0]'
        },
        # 29A
        'hasBurialExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForBurialCostYes[0]'
        },
        # 29B
        'hasConfirmation' => {
          key: 'form1[0].#subform[83].CertifyUnclaimed[0]'
        }
      }.freeze
      # rubocop:enable Layout/LineLength

      ##
      # Expands the form data for Section 5.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        expand_burial_allowance(form_data)
        expand_burial_expense_responsibility(form_data)
        expand_confirmation_question(form_data)
        expand_location_of_death(form_data)
        expand_death_under_va_covered_home_hospice_care(form_data)
        expand_veteran_transferred_to_va_covered_home_hospice_care(form_data)
      end

      ##
      # Expands the burial allowance request by ensuring values are formatted as '1' or 'Off'
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_burial_allowance(form_data)
        form_data['hasPreviouslyReceivedAllowance'] = select_radio(form_data['previouslyReceivedAllowance'])

        burial_allowance = form_data['burialAllowanceRequested']
        return if burial_allowance.blank?

        burial_allowance.each do |key, value|
          burial_allowance[key] = value.present? ? '1' : 'Off'
        end

        form_data['burialAllowanceRequested'] = {
          'checkbox' => burial_allowance
        }
      end

      ##
      # Expands the burial expense responsibility field (29A)
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_burial_expense_responsibility(form_data)
        return if form_data['burialExpenseResponsibility'].blank?

        form_data['hasBurialExpenseResponsibility'] = select_radio(form_data['burialExpenseResponsibility'])
      end

      ##
      # Expands the 'confirmation' field in the form data
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_confirmation_question(form_data)
        if form_data['confirmation'].present?
          confirmation = form_data['confirmation']
          form_data['hasConfirmation'] = select_radio(confirmation['checkBox'])
        end
      end

      ##
      # Converts the location of death by formatting facility details and adjusting specific location values
      #
      # @param form_data [Hash]
      #
      # @return [void]
      #
      def expand_location_of_death(form_data)
        location_of_death = form_data['locationOfDeath']
        return if location_of_death.blank?

        home_hospice_care = form_data['homeHospiceCare']
        home_hospice_care_after_discharge = form_data['homeHospiceCareAfterDischarge']

        location = location_of_death['location']
        options = form_data[location]
        if options.present? && location != 'other'
          form_data['placeAndLocation'] = "#{options['facilityName']} - #{options['facilityLocation']}"
        end

        form_data.delete(location)

        # Map atHome based on hospice care to appropriate nursing home option
        if location == 'atHome' && home_hospice_care && home_hospice_care_after_discharge
          location = 'nursingHomePaid'
        elsif location == 'atHome' && !(home_hospice_care && home_hospice_care_after_discharge)
          location = 'nursingHomeUnpaid'
        end

        # Set radiobutton value based on location using Constants mapping
        form_data['locationOfDeath'] = Constants::LOCATION_OF_DEATH[location]
      end

      ##
      # Expands the death under VA covered home hospice care field (27A)
      #
      # @param form_data [Hash]
      #
      # @return [void]
      #
      def expand_death_under_va_covered_home_hospice_care(form_data)
        return if form_data['homeHospiceCare'].blank?

        form_data['deathUnderVaCoveredHomeHospiceCare'] = select_radio(form_data['homeHospiceCare'])
      end

      ##
      # Expands the veteran transferred to VA covered home hospice care field (27B)
      #
      # @param form_data [Hash]
      #
      # @return [void]
      #
      def expand_veteran_transferred_to_va_covered_home_hospice_care(form_data)
        return if form_data['homeHospiceCareAfterDischarge'].blank?

        form_data['veteranTransferredToVaCoveredHomeHospiceCare'] =
          select_radio(form_data['homeHospiceCareAfterDischarge'])
      end
    end
  end
end
