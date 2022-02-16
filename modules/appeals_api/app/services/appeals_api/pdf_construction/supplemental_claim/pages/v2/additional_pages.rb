# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module Pages
        module V2
          class AdditionalPages
            def initialize(pdf, form_data)
              @pdf = pdf # Prawn::Document
              @form_data = form_data
            end

            def build!
              pdf.start_new_page

              pdf.text "\n<b>Veteran Email:</b>\n#{form_data.email}\n", inline_format: true unless short_veteran_email?

              pdf.text("\n<b>Additional Issues</b>\n", inline_format: true)
              pdf.table(extra_issues_table_data, width: 540, header: true)

              pdf.text("\n<b>Additional Evidence Names and Locations</b>\n", inline_format: true)
              pdf.table(extra_locations_table_data, width: 540, header: true)
            end

            private

            attr_accessor :pdf, :form_data

            def extra_issues_table_data
              header = ['A. Specific Issue(s)', 'B. Date of Decision', 'C. SOC/SSOC Date']

              data = form_data.contestable_issues.drop(max_issues_on_form).map do |issue|
                [issue.text, issue.decision_date, issue.soc_date_formatted]
              end

              data.unshift(header)
            end

            def extra_locations_table_data
              header = ['A. Name and Location', 'B. Date(s) of Records']

              locations = form_data.new_evidence_locations.drop(max_evidence_locations_on_form)
              evidence_dates = form_data.new_evidence_dates.drop(max_evidence_locations_on_form)

              data = locations.each_with_index.map do |location, i|
                dates = evidence_dates[i].join(', ')

                [location, dates]
              end

              data.unshift(header)
            end

            def max_issues_on_form
              AppealsApi::PdfConstruction::SupplementalClaim::V2::Structure::MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM
            end

            def max_evidence_locations_on_form
              AppealsApi::PdfConstruction::SupplementalClaim::V2::Structure::MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM
            end

            def short_email_length
              AppealsApi::PdfConstruction::SupplementalClaim::V2::Structure::SHORT_EMAIL_LENGTH
            end

            def short_veteran_email?
              form_data.email.length <= short_email_length
            end
          end
        end
      end
    end
  end
end
