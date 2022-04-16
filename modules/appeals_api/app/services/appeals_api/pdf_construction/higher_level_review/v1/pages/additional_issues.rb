# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V1
      module Pages
        class AdditionalIssues
          MAX_ISSUES_ON_FIRST_PAGE = 6

          def initialize(pdf, form_data)
            @pdf = pdf # Prawn::Document
            @form_data = form_data
          end

          def build!
            return pdf unless extra_issues?

            pdf.start_new_page

            pdf.text(extra_issues_text, inline_format: true)

            pdf
          end

          private

          attr_accessor :pdf, :form_data

          def extra_issues?
            form_data.contestable_issues.count > MAX_ISSUES_ON_FIRST_PAGE
          end

          def extra_issues_text
            issues = []

            form_data.contestable_issues.drop(MAX_ISSUES_ON_FIRST_PAGE).map do |issue|
              issues << "Issue: #{issue.text} - Decision Date: #{issue.decision_date}"
            end

            # keep parity between original HLR and new generator
            issues.reverse.join("\n")
          end
        end
      end
    end
  end
end
