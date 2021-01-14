# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      module Pages
        class HearingTypeAndAdditionalIssues
          def initialize(pdf, form_data)
            @pdf = pdf # Prawn::Document
            @form_data = form_data
          end

          def build!
            return pdf if no_content

            pdf.start_new_page

            pdf.text(hearing_type_text, inline_format: true)

            return pdf unless extra_issues?

            pdf.text("\n<b>Additional Issues</b>\n", inline_format: true)
            pdf.table(extra_issues_table_data, header: true)

            pdf
          end

          private

          attr_accessor :pdf, :form_data, :notice_of_disagreement

          def no_content
            !extra_issues? && no_hearing_type?
          end

          def no_hearing_type?
            form_data.hearing_type_preference.blank?
          end

          def extra_issues?
            form_data.contestable_issues.count > 5
          end

          def hearing_type_text
            return if no_hearing_type?

            "\nHearing Type Preference: #{form_data.hearing_type_preference.humanize}\n"
          end

          def extra_issues_table_data
            header = ['A. Specific Issue(s)', 'B. Date of Decision']

            data = form_data.contestable_issues.drop(5).map do |issue|
              [issue['attributes']['issue'], issue['attributes']['decisionDate']]
            end

            data.unshift(header)
          end
        end
      end
    end
  end
end
