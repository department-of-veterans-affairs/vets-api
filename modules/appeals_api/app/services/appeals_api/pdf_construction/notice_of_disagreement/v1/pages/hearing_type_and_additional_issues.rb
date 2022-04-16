# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V1
      module Pages
        class HearingTypeAndAdditionalIssues
          MAX_ISSUES_ON_FIRST_PAGE = 5

          def initialize(pdf, form_data)
            @pdf = pdf # Prawn::Document
            @form_data = form_data
          end

          def build!
            return pdf if no_content

            pdf.start_new_page

            pdf.text(hearing_type_text, inline_format: true)
            pdf.text(preferred_email_text, inline_format: true)

            return pdf unless extra_issues?

            pdf.text("\n<b>Additional Issues</b>\n", inline_format: true)
            pdf.table(extra_issues_table_data, width: 540, header: true)

            pdf
          end

          private

          attr_accessor :pdf, :form_data

          def no_content
            !extra_issues? && no_hearing_type? && short_preferred_email?
          end

          def no_hearing_type?
            form_data.hearing_type_preference.blank?
          end

          def extra_issues?
            form_data.contestable_issues.count > MAX_ISSUES_ON_FIRST_PAGE
          end

          def short_preferred_email?
            form_data.preferred_email.length <= 120
          end

          def hearing_type_text
            return if no_hearing_type?

            "\n<b>Hearing Type Preference:</b>\n#{form_data.hearing_type_preference.humanize}\n"
          end

          def preferred_email_text
            return if short_preferred_email?

            "\n<b>Preferred Email:</b>\n#{form_data.preferred_email}\n"
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
