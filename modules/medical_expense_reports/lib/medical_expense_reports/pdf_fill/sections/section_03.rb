# frozen_string_literal: true

require 'medical_expense_reports/pdf_fill/section'

module MedicalExpenseReports
  module PdfFill
    # Section III: Reporting Period
    class Section3 < Section
      # Section configuration hash
      KEY = {
        'reportingPeriod' => {
          'from' => {
            key: 'form1[0].#subform[9].Date_From[0]'
          },
          'to' => {
            key: 'form1[0].#subform[9].Date_To[0]'
          }
        },
        'firstTimeReporting' => {
          key: 'form1[0].#subform[9].Date_Received_By_For_Initial_Applications_Only[0]'
        }
      }.freeze

      # expand reporting period
      def expand(form_data = {})
        form_data['firstTimeReporting'] = form_data['firstTimeReporting'] ? '1' : 'Off'
        form_data
      end
    end
  end
end
