# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V3
      module Pages
        class AdditionalIssues
          def initialize(pdf, form_data)
            @pdf = pdf # Prawn::Document
            @form_data = form_data
          end

          def build!
            return pdf if no_content?

            pdf.start_new_page

            unless short_veteran_email?
              pdf.text "\n<b>Veteran Email:</b>\n#{form_data.veteran.email}\n", inline_format: true
            end

            unless short_claimant_email?
              pdf.text "\n<b>Claimant Email:</b>\n#{form_data.claimant.email}\n", inline_format: true
            end

            unless short_rep_email?
              pdf.text "\n<b>Representative Email:</b>\n#{form_data.rep_email}\n", inline_format: true
            end

            return pdf unless extra_issues?

            pdf.text("\n<b>Additional Issues</b>\n", inline_format: true)
            pdf.table(extra_issues_table_data, width: 540, header: true)
            pdf
          end

          private

          attr_accessor :pdf, :form_data

          def no_content?
            !extra_issues? && all_emails_short?
          end

          def extra_issues?
            form_data.contestable_issues.count > Structure::MAX_ISSUES_ON_MAIN_FORM
          end

          def all_emails_short?
            short_veteran_email? && short_claimant_email? && short_rep_email?
          end

          def short_veteran_email?
            form_data.veteran.email.length <= Structure::SHORT_EMAIL_THRESHOLD
          end

          def short_claimant_email?
            form_data.claimant.email.length <= Structure::SHORT_EMAIL_THRESHOLD
          end

          def short_rep_email?
            form_data.rep_email.length <= Structure::SHORT_EMAIL_THRESHOLD
          end

          def extra_issues_table_data
            header = ['A. Specific Issue(s)', 'B. Area of Disagreement', 'C. Date of Decision', 'D. SOC/SSOC Date']

            data = form_data.contestable_issues.drop(Structure::MAX_ISSUES_ON_MAIN_FORM).map do |issue|
              [issue.text, issue.disagreement_area, issue.decision_date, issue.soc_date_formatted]
            end

            data.unshift(header)
          end
        end
      end
    end
  end
end
