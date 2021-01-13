require 'prawn/table'

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      class Structure
        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
        end

        def form_fill
          options = {
            form_fields.veteran_name                      => form_data.veteran_name,
            form_fields.veteran_ssn                       => form_data.veteran_ssn,
            form_fields.veteran_file_number               => form_data.veteran_file_number,
            form_fields.date_signed                       => form_data.veteran_dob,
            form_fields.mailing_address_number_and_street => form_data.mailing_address_number_and_street,
            form_fields.homeless?                         => form_data.homeless?,
            form_fields.preferred_phone                   => form_data.preferred_phone,
            form_fields.preferred_email                   => form_data.preferred_email,
            form_fields.direct_review?                    => form_data.direct_review?,
            form_fields.evidence_submission?              => form_data.evidence_submission?,
            form_fields.hearing?                          => form_data.hearing?,
            form_fields.additional_pages?                 => form_data.additional_pages?,
            form_fields.soc_opt_in?                       => form_data.soc_opt_in?,
            form_fields.signature                         => form_data.signature,
            form_fields.date_signed                       => form_data.date_signed,
          }

          fill_first_five_issue_dates!(options)
        end

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
              form_data.representatives_name,
              text_opts.merge(
                at: [350, 512],
                width: 195,
                height: 24
              ))

            form_data.
              contestable_issues.
              take(5).
              each_with_index do |issue, index|
                ypos = 288 - (45 * index)
                pdf.text_box issue['attributes']['issue'],
                  text_opts.merge(
                    at: [0, ypos],
                    width: 444,
                    height: 38,
                    valign: :top
                  )
              end

            2.times { pdf.start_new_page } # temp file and pdf template must have same num of pages for pdftk.multistamp
          end

          pdftk.multistamp(form_fill_path, temp_path, output_path)

          output_path
        end

        def add_additional_pages
          return unless form_data.additional_pages?

          additional_pages_pdf

          add_hearing_type_and_extra_issues_page

          #additional_pages_pdf.start_new_page before each new page method

          additional_pages_pdf
        end

        def form_title
          '10182'
        end

        def stamp(stamped_pdf_path)
          CentralMail::DatestampPdf.new(stamped_pdf_path).run(
            text: form_data.stamp_text,
            x: 5,
            y: 775,
            text_only: true
          )
        end

        private

        attr_accessor :notice_of_disagreement

        def form_fields
          @form_fields ||= NoticeOfDisagreement::FormFields.new
        end

        def form_data
          @form_data ||= NoticeOfDisagreement::FormData.new(notice_of_disagreement)
        end

        def additional_pages_pdf
          @additional_pages_pdf ||= Prawn::Document.new
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

        def add_hearing_type_and_extra_issues_page
          additional_pages_pdf.text(hearing_type_text, inline_format: true)
          additional_pages_pdf.text("\n<b>Additional Issues</b>\n", inline_format: true)
          additional_pages_pdf.table(extra_issues_table_data, header: true)
        end

        def hearing_type_text
          return if notice_of_disagreement.hearing_type_preference.blank?

          "\nHearing Type Preference: #{notice_of_disagreement.hearing_type_preference.humanize}\n"
        end

        def extra_issues_table_data
          header = ['A. Specific Issue(s)', 'B. Date of Decision']

          data = form_data.contestable_issues.drop(5).map do |issue|
            [issue['attributes']['issue'], issue['attributes']['decisionDate']]
          end

          data.unshift(header)
        end

        def method_missing(method, *args, &block)
          if notice_of_disagreement.respond_to?(method)
            notice_of_disagreement.send(method)
          else
            super
          end
        end
      end
    end
  end
end
