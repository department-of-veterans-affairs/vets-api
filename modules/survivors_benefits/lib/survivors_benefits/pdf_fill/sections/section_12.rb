# frozen_string_literal: true

require 'survivors_benefits/pdf_fill/section'

module SurvivorsBenefits
  module PdfFill
    # Section XII: Claim Certification And Signature
    class Section12 < Section
      KEY = {
        'p18HeaderVeteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[218].VeteransSocialSecurityNumber_FirstThreeNumbers[8]'
          },
          'second' => {
            key: 'form1[0].#subform[218].VeteransSocialSecurityNumber_SecondTwoNumbers[8]'
          },
          'third' => {
            key: 'form1[0].#subform[218].VeteransSocialSecurityNumber_LastFourNumbers[8]'
          }
        },
        'dateSigned' => {
          'month' => {
            key: 'form1[0].#subform[218].Date_Signed_Month[1]'
          },
          'day' => {
            key: 'form1[0].#subform[218].Date_Signed_Day[1]'
          },
          'year' => {
            key: 'form1[0].#subform[218].Date_Signed_Year[1]'
          }
        }
      }.freeze

      def expand(form_data = {})
        form_data['p18HeaderVeteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['dateSigned'] = split_date(
          form_data['dateSigned'] || Time.zone.today.strftime('%Y-%m-%d')
        )
        form_data
      end
    end
  end
end
