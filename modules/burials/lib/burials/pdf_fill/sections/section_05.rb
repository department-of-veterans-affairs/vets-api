# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section V: Burial Allowance Information
    class Section5 < Section
      # rubocop:disable Layout/LineLength
      # Section configuration hash
      KEY = {
        # 20A
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
        # 20B
        'locationOfDeath' => {
          'checkbox' => {
            'nursingHomeUnpaid' => {
              key: 'form1[0].#subform[83].NursingHomeOrResidenceNotPaid[1]'
            },
            'nursingHomePaid' => {
              key: 'form1[0].#subform[83].NursingHomeOrResidencePaid[1]'
            },
            'vaMedicalCenter' => {
              key: 'form1[0].#subform[83].VaMedicalCenter[1]'
            },
            'stateVeteransHome' => {
              key: 'form1[0].#subform[83].StateVeteransHome[1]'
            },
            'other' => {
              key: 'form1[0].#subform[83].DeathOccurredOther[1]'
            }
          },
          'other' => {
            key: 'form1[0].#subform[37].DeathOccurredOtherSpecify[1]',
            question_num: 20,
            question_suffix: 'B',
            question_label: "Where Did The Veteran's Death Occur?",
            question_text: "WHERE DID THE VETERAN'S DEATH OCCUR?",
            limit: 32
          },
          'placeAndLocation' => {
            limit: 42,
            question_num: 20,
            question_suffix: 'B',
            question_label: "Please Provide Veteran's Specific Place Of Death Including The Name And Location Of The Nursing Home, Va Medical Center Or State Veteran Facility.",
            question_text: "PLEASE PROVIDE VETERAN'S SPECIFIC PLACE OF DEATH INCLUDING THE NAME AND LOCATION OF THE NURSING HOME, VA MEDICAL CENTER OR STATE VETERAN FACILITY.",
            key: 'form1[0].#subform[37].DeathOccurredPlaceAndLocation[1]'
          }
        },
        # 21
        'hasPreviouslyReceivedAllowance' => {
          key: 'form1[0].#subform[83].PreviousAllowance[0]'
        },
        # 22A
        'hasBurialExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForBurialCostYes[0]'
        },
        'noBurialExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForBurialCostNo[0]'
        },
        # 22B
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
        expand_checkbox_in_place(form_data, 'burialExpenseResponsibility')
        expand_burial_allowance(form_data)
        expand_confirmation_question(form_data)
        expand_location_of_death(form_data)
      end

      ##
      # Expands the burial allowance request by ensuring values are formatted as 'On' or nil
      #
      # @param form_data [Hash]
      #
      # @return [void]
      def expand_burial_allowance(form_data)
        form_data['hasPreviouslyReceivedAllowance'] = select_radio(form_data['previouslyReceivedAllowance'])
        burial_allowance = form_data['burialAllowanceRequested']
        return if burial_allowance.blank?

        burial_allowance.each do |key, value|
          burial_allowance[key] = value.present? ? 'On' : nil
        end

        form_data['burialAllowanceRequested'] = {
          'checkbox' => burial_allowance
        }
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
          location_of_death['placeAndLocation'] = "#{options['facilityName']} - #{options['facilityLocation']}"
        end

        form_data.delete(location)

        if location == 'atHome' && home_hospice_care && home_hospice_care_after_discharge
          location_of_death['location'] = 'nursingHomePaid'
        elsif location == 'atHome' && !(home_hospice_care && home_hospice_care_after_discharge)
          location_of_death['location'] = 'nursingHomeUnpaid'
        end

        expand_checkbox_as_hash(form_data['locationOfDeath'], 'location')
      end
    end
  end
end
