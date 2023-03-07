# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V3
        module Pages
          class AdditionalPages
            def initialize(pdf, form_data)
              @pdf = pdf # Prawn::Document
              @form_data = form_data
            end

            # rubocop:disable Metrics/MethodLength
            def build!
              pdf.start_new_page

              if form_data.long_email?
                pdf.text(
                  "\n<b>Veteran, claimant, or representative Email:</b>\n#{form_data.signing_appellant.email}\n",
                  inline_format: true
                )
              end

              if (table_data = extra_issues_table_data).present?
                pdf.text("\n<b>Additional Issues</b>\n", inline_format: true)
                pdf.table(table_data, width: 540, header: true)
              end

              if (table_data = extra_locations_dates_table_data).present?
                pdf.text("\n<b>Additional Evidence Names and Locations</b>\n", inline_format: true)
                pdf.table(table_data, width: 540, header: true)
              end

              if form_data.long_signature?
                pdf.text(
                  "\n\n\n\n\n<b>Signature of veteran, claimant, or representative:</b>\n #{form_data.signature}",
                  inline_format: true
                )
              end

              pdf
            end
            # rubocop:enable Metrics/MethodLength

            private

            attr_accessor :pdf, :form_data

            def extra_issues_table_data
              data = form_data.contestable_issues.drop(Structure::MAX_ISSUES_ON_MAIN_FORM).map do |issue|
                [issue.text, issue.decision_date, issue.soc_date_formatted]
              end

              data.unshift(['A. Specific Issue(s)', 'B. Date of Decision', 'C. SOC/SSOC Date']) unless data.empty?
            end

            def extra_locations_dates_table_data
              locations = form_data.new_evidence_locations.drop(Structure::MAX_EVIDENCE_LOCATIONS_ON_MAIN_FORM)
              dates = form_data.new_evidence_dates.drop(Structure::MAX_EVIDENCE_LOCATIONS_ON_MAIN_FORM)

              data = locations.each_with_index.map do |location, i|
                [location, dates[i].join(', ')]
              end

              data.unshift(['A. Name and Location', 'B. Date(s) of Records']) unless data.empty?
            end
          end
        end
      end
    end
  end
end
