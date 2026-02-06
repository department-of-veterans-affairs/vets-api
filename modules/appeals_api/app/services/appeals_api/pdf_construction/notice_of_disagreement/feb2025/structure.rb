# frozen_string_literal: true

require 'prawn/table'
require 'common/file_helpers'

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::Feb2025
      class Structure
        MAX_ISSUES_ON_MAIN_FORM = 5

        # Limit the combined Name fields(1. Veterans Name, 2. Appellant Name, 12. Signature)
        # length so that if it does get truncated it's consistent across all 3 fields
        MAX_COMBINED_NAME_FIELD_LENGTH = 164

        # Max number of charaters that fits on 1 line in the Specific Issues Column
        MAX_ISSUE_TABLE_COLUMN_LINE_LENGTH = 96

        attr_reader :notice_of_disagreement
        attr_accessor :form_fields, :form_data

        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
          @form_fields ||= FormFields.new
          @form_data ||= FormData.new(notice_of_disagreement)
        end

        def form_fill
          options = {
            form_fields.veteran_file_number => form_data.veteran.file_number,
            form_fields.veteran_dob => form_data.veteran.birth_date_string,
            form_fields.claimant_dob => form_data.claimant.birth_date_string,
            form_fields.homeless => form_data.veteran_homeless,
            form_fields.board_review_option => form_data.board_review_option,
            form_fields.board_review_option_hearing_type => form_data.board_review_option_hearing_type,
            form_fields.requesting_extension => form_data.requesting_extension,
            form_fields.appealing_vha_denial => form_data.appealing_vha_denial,
            form_fields.additional_issues => overflow_issues? ? 1 : 'Off',
            form_fields.date_signed => form_data.date_signed
          }

          fill_first_five_issue_dates!(options)
        end

        # rubocop:disable Metrics/MethodLength
        def insert_overlaid_pages(form_fill_path)
          pdftk = PdfForms.new(Settings.binaries.pdftk)
          temp_path = "/#{::Common::FileHelpers.random_file_path}.pdf"
          output_path = "/tmp/#{notice_of_disagreement.id}-overlaid-form-fill-tmp.pdf"

          Prawn::Document.generate(temp_path) do |pdf|
            text_opts = {
              overflow: :shrink_to_fit,
              min_font_size: 8,
              valign: :bottom
            }
            pdf.font 'Courier'

            pdf.text_box(
              form_data.veteran_full_name,
              text_opts.merge(
                at: [1, 662],
                width: 265, # So the width of the name & signature field match, for truncation consistency
                height: 24
              )
            )

            pdf.text_box(
              form_data.claimant_full_name,
              text_opts.merge(
                at: [1, 626],
                width: 390, # So the width of the name & signature field match, for truncation consistency
                height: 24
              )
            )

            pdf.text_box(
              form_data.mailing_address,
              text_opts.merge(
                at: [1, 590],
                width: 370,
                height: 42
              )
            )

            pdf.text_box(
              form_data.preferred_email,
              text_opts.merge(
                at: [188, 537],
                width: 176,
                height: 24
              )
            )

            pdf.text_box(
              form_data.preferred_phone,
              text_opts.merge(
                at: [1, 526],
                width: 183,
                height: 14
              )
            )

            pdf.text_box(
              form_data.rep_name,
              text_opts.merge(
                at: [368, 537],
                width: 176,
                height: 24
              )
            )

            insert_issues_into_text_boxes(pdf, text_opts)

            pdf.text_box(
              form_data.signature,
              text_opts.merge(
                at: [-4, 32],
                width: 398,
                height: 24
              )
            )

            2.times { pdf.start_new_page } # temp file and pdf template must have same num of pages for pdftk.multistamp
          end

          pdftk.multistamp(form_fill_path, temp_path, output_path)

          output_path
        end
        # rubocop:enable Metrics/MethodLength

        def whiteout(pdf, at:, width:, height: 15)
          pdf.fill_color 'ff0000'
          pdf.fill_rectangle(at, width, height)
          pdf.fill_color '000000'
        end

        def add_additional_pages
          return unless additional_pages?

          @additional_pages_pdf ||= Prawn::Document.new(skip_page_creation: true)

          Pages::LongDataAndExtraIssues.new(
            @additional_pages_pdf, form_data
          ).build!

          Pages::TimeExtensionReason.new(
            @additional_pages_pdf, form_data
          ).build!

          @additional_pages_pdf
        end

        def form_title
          '10182_feb2025'
        end

        # returns nil or a `pdftk.cat` array of page adjustments
        def final_page_adjustments
          return unless additional_pages?

          # moves pages 2 & 3 of the original form to the end of the document. Keeps all other pages.
          [1, '4-end', '2-3']
        end

        def self.issue_text_exceeds_column_width?(issue)
          # Issue Text wont fit in table column on single line
          return true if issue.text.strip.length > MAX_ISSUE_TABLE_COLUMN_LINE_LENGTH

          disagreement_area = "\nDisagreement: #{issue['attributes']['disagreementArea'].to_s.strip}"

          # Disagreement text wont fit in table column on single line
          disagreement_area.to_s.length > MAX_ISSUE_TABLE_COLUMN_LINE_LENGTH
        end

        private

        def fill_first_five_issue_dates!(options)
          # this method is a holdover from the previous constructor design,
          # where we use a resizable textbox drawn after the initial form fill
          # to handle the contestableIssue content, so we fill the date, and do
          # the content afterwards.
          form_row_index = 0

          form_data.contestable_issues.take(MAX_ISSUES_ON_MAIN_FORM).each do |issue|
            # skip date on form if text won't fit, this issue will show on overflow page
            next if self.class.issue_text_exceeds_column_width?(issue)

            options[form_fields.issue_table_decision_date(form_row_index)] = issue['attributes']['decisionDate']
            form_row_index += 1
          end

          options
        end

        def additional_pages?
          return true if overflow_issues?

          form_data.long_preferred_email? ||
            form_data.requesting_extension? ||
            form_data.long_rep_name?
        end

        def overflow_issues?
          return true if form_data.contestable_issues.length > MAX_ISSUES_ON_MAIN_FORM

          form_data.contestable_issues.any? do |issue|
            self.class.issue_text_exceeds_column_width?(issue)
          end
        end

        def insert_issues_into_text_boxes(pdf, text_opts)
          form_row_index = 0
          form_data.contestable_issues.take(MAX_ISSUES_ON_MAIN_FORM)
                   .select(&:text_exists?)
                   .reject { |issue| self.class.issue_text_exceeds_column_width?(issue) }
                   .map { |issue| issue_full_text(issue) }
                   .each do |full_text|
                     pdf.text_box(
                       full_text,
                       text_opts.merge({ at: [-4, 221 - (24 * form_row_index)], width: 465, height: 22,
                                         valign: :center })
                     )
                     form_row_index += 1
          end

          # display attached page notification only if all issues overflow(issues table is empty)
          if form_row_index.zero? && form_data.contestable_issues.length.positive?
            pdf.text_box('See attached page for additional issues',
                         text_opts.merge({ at: [-4, 221], width: 465, height: 22, valign: :center }))
          end
        end

        def issue_full_text(issue)
          full_text = issue.text.strip
          if (disagreement_area = issue['attributes']['disagreementArea'])
            full_text += "\nDisagreement: #{disagreement_area.strip}"
          end
          full_text
        end
      end
    end
  end
end
