# frozen_string_literal: true

require 'prawn/table'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V4
      class Structure
        MAX_ISSUES_FIRST_PAGE = 7
        MAX_ISSUES_SECOND_PAGE = 6
        MAX_ISSUES_ON_MAIN_FORM = (MAX_ISSUES_FIRST_PAGE + MAX_ISSUES_SECOND_PAGE).freeze
        SHORT_EMAIL_THRESHOLD = 100
        DEFAULT_TEXT_OPTIONS = { overflow: :shrink_to_fit, min_font_size: 8, valign: :bottom }.freeze

        def initialize(higher_level_review)
          @higher_level_review = higher_level_review
        end

        def form_title
          '200996_v4'
        end

        def form_fields
          @form_fields ||= FormFields.new
        end

        def form_data
          @form_data ||= FormData.new(higher_level_review)
        end

        def form_fill
          FormFields::FIELD_NAMES.keys.reduce({}) do |values, field_name|
            values.merge({ form_fields.send(field_name) => form_data.send(field_name) })
          end.merge(fill_contestable_issues_dates).merge(fill_benefit_type_fields)
        end

        def insert_overlaid_pages(form_fill_path)
          pdftk = PdfForms.new(Settings.binaries.pdftk)
          output_path = "/tmp/#{higher_level_review.id}-overlaid-form-fill-tmp.pdf"
          temp_path = fill_autosize_fields
          pdftk.multistamp(form_fill_path, temp_path, output_path)
          output_path
        end

        def add_additional_pages
          return unless additional_pages?

          @additional_pages_pdf ||= Prawn::Document.new(skip_page_creation: true)
          Pages::AdditionalIssues.new(@additional_pages_pdf, form_data).build!
          @additional_pages_pdf
        end

        def final_page_adjustments
          # no-op
        end

        private

        attr_accessor :higher_level_review

        # rubocop:disable Metrics/MethodLength
        def fill_autosize_fields
          tmp_path = "/#{::Common::FileHelpers.random_file_path}.pdf"
          Prawn::Document.generate(tmp_path) do |pdf|
            pdf.font 'Courier'

            %i[
              veteran_first_name veteran_last_name veteran_file_number veteran_number_and_street
              veteran_city veteran_zip_code veteran_international_phone veteran_email
              claimant_first_name claimant_last_name claimant_number_and_street claimant_email
              claimant_city claimant_zip_code claimant_international_phone
            ].each { |field_name| fill_text(pdf, field_name) }

            fill_text pdf, :veteran_email,
                      max_length: SHORT_EMAIL_THRESHOLD,
                      long_text_override: 'See attached page for veteran email'
            fill_text pdf, :claimant_email,
                      max_length: SHORT_EMAIL_THRESHOLD,
                      long_text_override: 'See attached page for claimant email'

            pdf.start_new_page

            %i[rep_first_name rep_last_name rep_international_phone rep_phone_extension]
              .each { |field_name| fill_text(pdf, field_name) }

            fill_text pdf, :rep_email,
                      max_length: SHORT_EMAIL_THRESHOLD,
                      long_text_override: 'See attached page for representative email'
            fill_contestable_issues_text(pdf)
            pdf.text_box(form_data.veteran_claimant_signature,
                         DEFAULT_TEXT_OPTIONS.merge(form_fields.boxes[:veteran_claimant_signature]))
          end
          tmp_path
        end
        # rubocop:enable Metrics/MethodLength

        def fill_benefit_type_fields
          { form_fields.benefit_type_field => form_data.benefit_type_code }
        end

        def additional_pages?
          form_data.contestable_issues.count > MAX_ISSUES_ON_MAIN_FORM || (
            (form_data.veteran_email || '').length > SHORT_EMAIL_THRESHOLD ||
              (form_data.claimant_email || '').length > SHORT_EMAIL_THRESHOLD ||
              (form_data.rep_email || '').length > SHORT_EMAIL_THRESHOLD
          )
        end

        def fill_contestable_issues_dates
          form_data.contestable_issues.take(MAX_ISSUES_ON_MAIN_FORM).each_with_index.reduce({}) do |data, (issue, i)|
            subform = i < MAX_ISSUES_FIRST_PAGE ? 3 : 4
            index = i
            date = issue.decision_date

            data.merge!({
                          form_fields.contestable_issue_month_field(subform, index) => date.strftime('%m'),
                          form_fields.contestable_issue_day_field(subform, index) => date.strftime('%d'),
                          form_fields.contestable_issue_year_field(subform, index) => date.strftime('%Y')
                        })
          end
        end

        def fill_contestable_issues_text(pdf)
          issues = form_data.contestable_issues.take(MAX_ISSUES_ON_MAIN_FORM)
          issues.first(MAX_ISSUES_FIRST_PAGE).each_with_index do |issue, i|
            fill_contestable_issue_text(issue, pdf, {
                                          issue_text: form_fields.boxes[:issue_pg1][i],
                                          soc_date: form_fields.boxes[:soc_date_pg1][i],
                                          disagreement_area: form_fields.boxes[:disagreement_area_pg1][i]
                                        })
          end

          pdf.start_new_page # Always start a new page even if there are no issues so other text can insert properly
          issues.drop(MAX_ISSUES_FIRST_PAGE).each_with_index do |issue, i|
            fill_contestable_issue_text(issue, pdf,
                                        {
                                          issue_text: form_fields.boxes[:issue_pg2][i],
                                          soc_date: form_fields.boxes[:soc_date_pg2][i],
                                          disagreement_area: form_fields.boxes[:disagreement_area_pg2][i]
                                        })
          end
        end

        def fill_contestable_issue_text(issue, pdf, boxes)
          if issue.text_exists?
            pdf.text_box(issue.text, DEFAULT_TEXT_OPTIONS.merge(boxes[:issue_text]))

            if (date = issue.soc_date_formatted).present?
              pdf.text_box("SOC/SSOC Date: #{date}", DEFAULT_TEXT_OPTIONS.merge(boxes[:soc_date]))
            end

            if issue.disagreement_area
              pdf.text_box("Area of Disagreement: #{issue.disagreement_area}",
                           DEFAULT_TEXT_OPTIONS.merge(boxes[:disagreement_area]))
            end
          end
        end

        def whiteout(pdf, at:, width:, height: 15)
          pdf.fill_color 'ffffff'
          pdf.fill_rectangle(at, width, height)
          pdf.fill_color '000000'
        end

        def fill_text(pdf, attr, long_text_override: nil, max_length: nil)
          text = form_data.send(attr)
          return if text.blank?

          text = long_text_override if max_length && long_text_override.present? && text.length > max_length
          text_opts = form_fields.boxes[attr].merge(DEFAULT_TEXT_OPTIONS).merge(height: 13)
          whiteout(pdf, **form_fields.boxes[attr])
          pdf.text_box text, text_opts
        end
      end
    end
  end
end
