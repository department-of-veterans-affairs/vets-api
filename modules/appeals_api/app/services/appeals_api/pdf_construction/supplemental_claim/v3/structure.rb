# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V3
        class Structure
          MAX_ISSUES_ON_MAIN_FORM = 6
          MAX_EVIDENCE_LOCATIONS_ON_MAIN_FORM = 3
          SHORT_EMAIL_THRESHOLD = 50
          DEFAULT_TEXT_OPTIONS = {
            height: 13,
            min_font_size: 8,
            overflow: :shrink_to_fit,
            valign: :bottom
          }.freeze

          def initialize(supplemental_claim)
            @supplemental_claim = supplemental_claim
          end

          def form_title
            '200995_v3'
          end

          def form_fields
            @form_fields ||= FormFields.new
          end

          def form_data
            @form_data ||= FormData.new(supplemental_claim)
          end

          def form_fill
            FormFields::FIELD_NAMES.keys.reduce({}) do |values, key|
              values.merge({ form_fields.send(key) => form_data.send(key) })
            end
          end

          def insert_overlaid_pages(form_fill_path)
            pdftk = PdfForms.new(Settings.binaries.pdftk)

            output_path = "/tmp/#{supplemental_claim.id}-overlaid-form-fill-tmp.pdf"

            temp_path = fill_autosize_fields
            pdftk.multistamp(form_fill_path, temp_path, output_path)
            output_path
          end

          def additional_issues?
            form_data.contestable_issues.count > MAX_ISSUES_ON_MAIN_FORM
          end

          def additional_evidence_locations?
            form_data.new_evidence_locations.count > MAX_EVIDENCE_LOCATIONS_ON_MAIN_FORM
          end

          def additional_pages?
            additional_issues? || additional_evidence_locations? || form_data.long_signature?
          end

          def add_additional_pages
            return unless additional_pages?

            @additional_pages_pdf ||= Prawn::Document.new(skip_page_creation: true)
            Pages::AdditionalPages.new(@additional_pages_pdf, form_data).build!
            @additional_pages_pdf
          end

          def final_page_adjustments
            ['3-end'] # Removes first 2 boilerplate pages
          end

          def whiteout(pdf, at:, width:, height: 14, **_ignored)
            pdf.fill_color 'ffffff'
            pdf.fill_rectangle at, width, height
            pdf.fill_color '000000'
          end

          def fill_text(pdf, attr, long_text_override: nil, length_for_override: SHORT_EMAIL_THRESHOLD)
            text = form_data.send(attr)
            return if text.blank?

            text = long_text_override if long_text_override.present? && text.length > length_for_override
            value = form_fields.boxes[attr]
            raise "Missing box values for #{attr}" if value.blank?

            text_opts = form_fields.boxes[attr].merge(DEFAULT_TEXT_OPTIONS)

            whiteout pdf, **form_fields.boxes[attr]

            pdf.text_box text, text_opts
          end

          def fill_contestable_issues_text(pdf)
            issues = form_data.contestable_issues.take(MAX_ISSUES_ON_MAIN_FORM)
            issues.first(MAX_ISSUES_ON_MAIN_FORM).each_with_index do |issue, i|
              if issue.text_exists?
                pdf.text_box(
                  issue.text,
                  DEFAULT_TEXT_OPTIONS.merge(form_fields.boxes[:contestable_issues][i])
                )
                pdf.text_box(
                  issue.decision_date_string,
                  DEFAULT_TEXT_OPTIONS.merge(form_fields.boxes[:decision_dates][i])
                )
                if (date = issue.soc_date_formatted)
                  pdf.text_box(
                    "SOC/SSOC Date: #{date}",
                    DEFAULT_TEXT_OPTIONS.merge(form_fields.boxes[:soc_dates][i])
                  )
                end
              end
            end
          end

          def fill_evidence_name_location_text(pdf)
            form_data.new_evidence_locations.take(MAX_EVIDENCE_LOCATIONS_ON_MAIN_FORM).each_with_index do |location, i|
              pdf.text_box(location, DEFAULT_TEXT_OPTIONS.merge(form_fields.boxes[:new_evidence_locations][i]))
            end
          end

          def fill_new_evidence_dates(pdf)
            form_data.new_evidence_dates.take(MAX_EVIDENCE_LOCATIONS_ON_MAIN_FORM).each_with_index do |dates, i|
              pdf.text_box(dates.join("\n"), DEFAULT_TEXT_OPTIONS.merge(form_fields.boxes[:new_evidence_dates][i]))
            end
          end

          # rubocop:disable Metrics/MethodLength
          def fill_autosize_fields
            tmp_path = "/#{::Common::FileHelpers.random_file_path}.pdf"

            Prawn::Document.generate(tmp_path) do |pdf|
              2.times { pdf.start_new_page }

              pdf.font 'Courier'

              fill_text pdf, :veteran_first_name
              fill_text pdf, :veteran_last_name
              fill_text pdf, :claimant_first_name
              fill_text pdf, :claimant_last_name
              fill_text pdf, :claimant_type_other_text
              fill_text pdf, :signing_appellant_number_and_street
              fill_text pdf, :signing_appellant_city
              fill_text pdf, :signing_appellant_zip_code
              fill_text pdf, :international_phone
              fill_text pdf, :signing_appellant_email, long_text_override: 'See attached page for appellant email'

              fill_contestable_issues_text pdf

              pdf.start_new_page

              fill_evidence_name_location_text pdf
              fill_new_evidence_dates pdf

              fill_text pdf, :veteran_claimant_rep_signature
              fill_text pdf, :alternate_signer_signature
              fill_text pdf, :alternate_signer_full_name
            end

            tmp_path
          end
          # rubocop:enable Metrics/MethodLength

          private

          attr_accessor :supplemental_claim
        end
      end
    end
  end
end
