# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

module MedicalExpenseReports
  module PdfFill
    # Section VII: Certification And Signature
    class Section7 < Section
      # Section configuration hash
      KEY = {
        'statementOfTruthSignature' => {
          key: 'form1[0].#subform[11].SignatureField1[0]'
        },
        'dateSigned' => {
          'month' => {
            key: 'form1[0].#subform[11].Date_Signed_Month[0]'
          },
          'day' => {
            key: 'form1[0].#subform[11].Date_Signed_Day[0]'
          },
          'year' => {
            key: 'form1[0].#subform[11].Date_Signed_Year[0]'
          }
        }
      }.freeze

      # expand date signed
      def expand(form_data = {})
        form_data['dateSigned'] = split_date(
          form_data['dateSigned'] || Time.zone.today.strftime('%Y-%m-%d')
        )
        form_data
      end
    end
  end
end
