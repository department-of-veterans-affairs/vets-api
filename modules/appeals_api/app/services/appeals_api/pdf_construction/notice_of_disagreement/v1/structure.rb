# frozen_string_literal: true

require 'prawn/table'
require 'common/file_helpers'

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V1
      class Structure
        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
        end

        def form_fill
          options = {
            # veteran name is filled as part of insert_overlaid_pages, for autosizing
            form_fields.veteran_ssn => form_data.veteran_ssn,
            form_fields.veteran_file_number => form_data.veteran_file_number,
            form_fields.veteran_dob => form_data.veteran_dob,
            form_fields.claimant_dob => form_data.claimant_dob,
            form_fields.mailing_address => form_data.mailing_address,
            form_fields.homeless => form_data.homeless,
            form_fields.preferred_phone => form_data.preferred_phone,
            form_fields.direct_review => form_data.direct_review,
            form_fields.evidence_submission => form_data.evidence_submission,
            form_fields.hearing => form_data.hearing,
            form_fields.extra_contestable_issues => form_data.extra_contestable_issues,
            form_fields.soc_opt_in => form_data.soc_opt_in,
            # signature is filled as part of insert_overlaid_pages, for autosizing
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
              form_data.veteran_name,
              text_opts.merge(
                at: [1, 660],
                width: 435, # So the width of the name & signature field match, for truncation consistency
                height: 16
              )
            )

            pdf.text_box(
              form_data.claimant_name,
              text_opts.merge(
                at: [1, 603],
                width: 370, # So the width of the name & signature field match, for truncation consistency
                height: 16
              )
            )

            pdf.text_box(
              preferred_email_field_text,
              text_opts.merge(
                at: [145, 514],
                width: 195,
                height: 24
              )
            )

            pdf.text_box(
              form_data.representative_name,
              text_opts.merge(
                at: [350, 514],
                width: 195,
                height: 24
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

          Pages::HearingTypeAndAdditionalIssues.new(
            @additional_pages_pdf, form_data
          ).build!

          @additional_pages_pdf
        end

        def form_title
          '10182'
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
          @form_fields ||= NoticeOfDisagreement::V1::FormFields.new
        end

        def form_data
          @form_data ||= NoticeOfDisagreement::V1::FormData.new(notice_of_disagreement)
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

        def additional_pages?
          form_data.hearing_type_preference.present? ||
            form_data.contestable_issues.count > 5 ||
            !short_preferred_email?
        end

        # rubocop:disable Metrics/MethodLength
        def insert_issues_into_text_boxes(pdf, text_opts)
          form_data
            .contestable_issues
            .take(5)
            .each_with_index do |issue, index|
              ypos = 288 - (45 * index)
              pdf.text_box issue['attributes']['issue'],
                           text_opts.merge(
                             at: [0, ypos],
                             width: 444,
                             height: 19,
                             valign: :top
                           )

              next unless issue['attributes']['disagreementArea']

              pdf.text_box "Area of Disagreement: #{issue['attributes']['disagreementArea']}",
                           text_opts.merge(
                             at: [0, ypos - 19],
                             width: 444,
                             height: 19,
                             valign: :bottom
                           )
            end
        end
        # rubocop:enable Metrics/MethodLength

        def short_preferred_email?
          # preferred email will be present since it's required & has minLength set
          form_data.preferred_email.length <= 120
        end

        def preferred_email_field_text
          short_preferred_email? ? form_data.preferred_email : 'See attached page for preferred email'
        end
      end
    end
  end
end
