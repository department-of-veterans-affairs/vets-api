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
            form_fields.preferred_phone                   => form_data.veteran_name,
            form_fields.preferred_email                   => form_data.veteran_name,
            form_fields.direct_review?                    => form_data.veteran_name,
            form_fields.evidence_submission?              => form_data.veteran_name,
            form_fields.hearing?                          => form_data.veteran_name,
            form_fields.additional_pages?                 => form_data.veteran_name,
            form_fields.soc_opt_in?                       => form_data.veteran_name,
            form_fields.signature                         => form_data.signature,
            form_fields.date_signed                       => form_data.veteran_name,
          }

          fill_first_five_issue_dates!(options)
        end

        def insert_overlaid_pages(form_fill_path)
          pdftk = PdfForms.new(Settings.binaries.pdftk)
          temp_path = "/tmp/#{::Common::FileHelpers.random_file_path}.pdf"
          output_path = "/tmp/#{appeal.id}-overlaid-form-fill-tmp.pdf"

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
        end

        def add_additional_pages
          # this method must return a Prawn::Document object.

          add_extra_issues_and_rep_name

          @additional_pages_pdf
        end

        def form_title
          '10182'
        end

        def stamp(stamped_pdf_path)
          CentralMail::DatestampPdf.new(stamped_path).run(
            text: form_data.stamp_text,
            x: 5,
            y: 775,
            text_only: true
          )
        end

        private

        def form_fields
          @form_fields ||= NoticeOfDisagreement::FormFields.new
        end

        def form_data
          @form_data ||= NoticeOfDisagreement::FormData.new(@notice_of_disagreement)
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

        def method_missing(method, *args, &block)
          if @notice_of_disagreement.respond_to?(method)
            @notice_of_disagreement.send(method)
          else
            super
          end
        end
      end
    end
  end
end
