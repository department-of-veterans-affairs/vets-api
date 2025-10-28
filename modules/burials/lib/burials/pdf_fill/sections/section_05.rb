# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section V: Burial Allowance Information
    class Section5 < Section
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

      ##
      # Expands the form data for Section 5.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        # Add expansion logic here
      end
    end
  end
end
