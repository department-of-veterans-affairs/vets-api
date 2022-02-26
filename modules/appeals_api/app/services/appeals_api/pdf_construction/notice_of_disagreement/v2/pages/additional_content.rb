# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V2
      module Pages
        class AdditionalContent
          MAX_ISSUES_ON_FIRST_PAGE = 5

          def initialize(pdf, form_data)
            @pdf = pdf # Prawn::Document
            @form_data = form_data
          end

          def build!
            return pdf if no_content

            pdf.start_new_page

            pdf.text(preferred_email_text, inline_format: true)

            return pdf unless extra_issues?

            pdf.text("\n<b>Additional Issues</b>\n", inline_format: true)
            pdf.table(extra_issues_table_data, width: 540, header: true)

            pdf
          end

          private

          attr_accessor :pdf, :form_data

          def no_content
            !extra_issues? && !form_data.extension_request? && !form_data.long_preferred_email?
          end

          def extra_issues?
            form_data.contestable_issues.count > MAX_ISSUES_ON_FIRST_PAGE
          end

          def preferred_email_text
            return unless form_data.long_preferred_email?

            "\n<b>Preferred Email:</b>\n#{form_data.signing_appellant.email}\n"
          end

          def extra_issues_table_data
            header = ['A. Specific Issue(s)', 'B. Area of Disagreement', 'C. Date of Decision']

            data = form_data.contestable_issues.drop(MAX_ISSUES_ON_FIRST_PAGE).map do |issue|
              [issue['attributes']['issue'], issue['attributes']['disagreementArea'],
               issue['attributes']['decisionDate']]
            end

            data.unshift(header)
          end
        end
      end
    end
  end
end
