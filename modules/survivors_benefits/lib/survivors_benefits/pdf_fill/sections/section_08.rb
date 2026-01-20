# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    # Section VIII: Nursing Home or Increased Survivors Entitlement
    class Section8 < Section
      # Section configuration hash
      KEY = {
        'claimingMonthlySpecialPension' => {
          key: 'form1[0].#subform[211].RadioButtonList[30]'
        },
        'claimantLivesInANursingHome' => {
          key: 'form1[0].#subform[211].RadioButtonList[31]'
        }
      }.freeze

      def expand(form_data = {})
        form_data['claimingMonthlySpecialPension'] =
          case form_data['claimingMonthlySpecialPension']
          when true then 1
          when false then 'NO'
          else 'Off'
          end

        form_data['claimantLivesInANursingHome'] =
          if form_data['claimantLivesInANursingHome'].nil?
            'Off'
          else
            form_data['claimantLivesInANursingHome'] ? 0 : 1 # reversed, careful
          end

        form_data
      end
    end
  end
end
