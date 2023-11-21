# frozen_string_literal: true

require 'prawn/table'
require 'common/file_helpers'

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V2
      class Structure
        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
        end

        def form_fill
          options = {
            form_fields.veteran_file_number => form_data.veteran.file_number,
            form_fields.veteran_dob => form_data.veteran.birth_date_string,
            form_fields.claimant_dob => form_data.claimant.birth_date_string,
            form_fields.mailing_address => form_data.mailing_address,
            form_fields.homeless => form_data.veteran_homeless,
            form_fields.preferred_phone => form_data.preferred_phone,
            form_fields.direct_review => form_data.direct_review,
            form_fields.evidence_submission => form_data.evidence_submission,
            form_fields.hearing => form_data.hearing,
            form_fields.central_office_hearing => form_data.central_office_hearing,
            form_fields.video_conference_hearing => form_data.video_conference_hearing,
            form_fields.virtual_tele_hearing => form_data.virtual_tele_hearing,
            form_fields.requesting_extension => form_data.requesting_extension,
            form_fields.appealing_vha_denial => form_data.appealing_vha_denial,
            form_fields.additional_issues => form_data.additional_pages,
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
              form_data.veteran.full_name,
              text_opts.merge(
                at: [1, 670],
                width: 210, # So the width of the name & signature field match, for truncation consistency
                height: 16
              )
            )

            pdf.text_box(
              form_data.claimant.full_name,
              text_opts.merge(
                at: [1, 641],
                width: 370, # So the width of the name & signature field match, for truncation consistency
                height: 16
              )
            )

            pdf.text_box(
              form_data.preferred_email,
              text_opts.merge(
                at: [145, 550],
                width: 195,
                height: 24
              )
            )

            pdf.text_box(
              form_data.rep_name,
              text_opts.merge(
                at: [348, 570],
                width: 200,
                height: 44
              )
            )

            insert_issues_into_text_boxes(pdf, text_opts)

            pdf.text_box(
              form_data.signature,
              text_opts.merge(
                at: [1, 29],
                width: 435,
                height: 24
              )
            )
            2.times { pdf.start_new_page } # temp file and pdf template must have same num of pages for pdftk.multistamp
          end

          pdftk.multistamp(form_fill_path, temp_path, output_path)

          output_path
        end
        # rubocop:enable Metrics/MethodLength

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
          '10182_v2'
        end

        # returns nil or a `pdftk.cat` array of page adjustments
        def final_page_adjustments
          return unless additional_pages?

          # moves pages 2 & 3 of the original form to the end of the document. Keeps all other pages.
          [1, '4-end', '2-3']
        end

        private

        attr_accessor :notice_of_disagreement

        def form_fields
          @form_fields ||= FormFields.new
        end

        def form_data
          @form_data ||= FormData.new(notice_of_disagreement)
        end

        def fill_first_five_issue_dates!(options)
          # this method is a holdover from the previous constructor design,
          # where we use a resizable textbox drawn after the initial form fill
          # to handle the contestableIssue content, so we fill the date, and do
          # the content afterwards.

          form_data.contestable_issues.take(5).each_with_index do |issue, index|
            options[form_fields.issue_table_decision_date(index)] = issue['attributes']['decisionDate']
          end

          options
        end
        # rubocop:disable Layout/LineLength

        def additional_pages?
          form_data.contestable_issues.count > 5 || form_data.long_preferred_email? || form_data.requesting_extension? || form_data.long_rep_name?
        end
        # rubocop:enable Layout/LineLength

        MAX_ISSUES_ON_MAIN_FORM = 5

        def insert_issues_into_text_boxes(pdf, text_opts)
          form_data.contestable_issues.take(MAX_ISSUES_ON_MAIN_FORM).each_with_index do |issue, i|
            if issue.text_exists?
              full_text = issue.text.strip

              if (disagreement_area = issue['attributes']['disagreementArea'])
                full_text += "\nArea of Disagreement: #{disagreement_area.strip}"
              end

              y_pos = 279 - (35 * i)
              pdf.text_box(
                full_text,
                text_opts.merge({ at: [0, y_pos], width: 444, height: 33, valign: :center })
              )
            end
          end
        end
      end
    end
  end
end
