# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

module MedicalExpenseReports
  module PdfFill
    # Section VII: Certification And Signature
    class Section7 < Section
      # Section configuration hash
      KEY = {
        'today' => {
          'month' => {
            key: "form1[0].#subform[11].Date_Signed_Month[0]"
          },
          'day' => {
            key: "form1[0].#subform[11].Date_Signed_Day[0]"
          },
          'year' => {
            key: "form1[0].#subform[11].Date_Signed_Year[0]"
          }
        }
      }.freeze

      def expand(form_data={})
        form_data['today'] = split_date(Date.today.strftime('%Y-%m-%d'))
        form_data
      end
    end
  end
end
