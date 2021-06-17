# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module Pages
        module V2
          class AdditionalIssues
            def initialize(pdf, form_data)
              @pdf = pdf # Prawn::Document
              @form_data = form_data
            end

            def build!
              return pdf if no_content

              pdf.start_new_page

              return pdf unless extra_issues?

              pdf.text("\n<b>Additional Issues</b>\n", inline_format: true)
              pdf.table(extra_issues_table_data, width: 540, header: true)

              pdf
            end

            private

            attr_accessor :pdf, :form_data

            def no_content
              !extra_issues?
            end

            def extra_issues?
              form_data.contestable_issues.count > max_issues_on_form
            end

            def extra_issues_table_data
              header = ['A. Specific Issue(s)', 'B. Date of Decision', 'C. SOC/SSOC Date']

              data = form_data.contestable_issues.drop(max_issues_on_form).map do |issue|
                [issue.text, issue.decision_date, issue.soc_date_formatted]
              end

              data.unshift(header)
            end

            def max_issues_on_form
              AppealsApi::PdfConstruction::HigherLevelReview::V2::Structure::MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM
            end
          end
        end
      end
    end
  end
end
