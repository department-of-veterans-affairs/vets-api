# frozen_string_literal: true

require 'common/file_helpers'
require 'pdf_fill/filler'

module AppealsApi
  module PdfDownloads
    extend ActiveSupport::Concern

    included do
      def render_appeal_pdf_download(appeal, filename, confirmation_icn)
        if expired?(appeal)
          # If the veteran_icn is available, we can check it against the current request's ICN parameter to return a 404
          # if it does not match, but otherwise, if the appeal has no PII, we can't tell whether the current request is
          # authorized, so in that case we return a specific error message regardless of authorization status.
          if download_authorized?(appeal, confirmation_icn)
            return render_pdf_download_expired(appeal)
          else
            raise ActiveRecord::RecordNotFound
          end
        end

        # We choose to return a 404 when PII in headers doesn't match the Appeal's PII so that we don't reveal the
        # existence of records that the user can't access
        raise ActiveRecord::RecordNotFound unless download_authorized?(appeal, confirmation_icn)

        return render_pdf_download_not_ready(appeal) unless submitted?(appeal)

        pdf_path = PdfDownloads.watermark(
          AppealsApi::PdfConstruction::Generator.new(appeal, pdf_version: appeal.pdf_version).generate,
          filename
        )

        send_file(pdf_path, type: 'application/pdf; charset=utf-8', filename:)
      end
    end

    # Creates a copy of the input PDF with a watermark on each page
    def self.watermark(input_path, output_path = "#{Common::FileHelpers.random_file_path}.pdf")
      num_pages = PDF::Reader.new(input_path).pages.length
      stamp_path = "#{Common::FileHelpers.random_file_path}-watermark.pdf"

      Prawn::Document.generate(stamp_path, margin: [10, 10]) do |pdf|
        num_pages.times do
          pdf.transparent(0.25) do
            pdf.text_box WATERMARK_MARKUP,
                         align: :center,
                         inline_format: true,
                         rotate: 45,
                         rotate_around: :center,
                         size: 52,
                         valign: :center,
                         overflow: :shrink_to_fit
          end
          pdf.start_new_page # Final extra page won't be added to output
        end
      end

      PdfFill::Filler::PDF_FORMS.multistamp(input_path, stamp_path, output_path)
      FileUtils.rm_f(stamp_path)

      output_path
    end

    UNSUBMITTED_STATUSES = %w[pending submitting error].freeze
    WATERMARK_MARKUP = '<b>DIGITALLY SUBMITTED<br>DO NOT FILE</b>'

    # Determines whether the download is allowed based on a provided ICN value and the appeal's original saved data
    def download_authorized?(appeal, confirmation_icn)
      if (saved_icn = appeal.veteran&.icn.presence || appeal.veteran_icn.presence)
        return saved_icn == confirmation_icn
      end

      false
    end

    def submitted?(appeal)
      UNSUBMITTED_STATUSES.exclude?(appeal.status) && appeal.pdf_version.present?
    end

    def expired?(appeal)
      appeal.class.pii_expunge_policy.exists?(appeal.id) || appeal.form_data.blank?
    end

    def render_pdf_download_not_ready(appeal)
      msg_key = if appeal.status == 'error'
                  'appeals_api.errors.pdf_download_in_error'
                else
                  'appeals_api.errors.pdf_download_not_ready'
                end

      render(
        status: :unprocessable_entity,
        json: {
          errors: [
            {
              code: '422',
              detail: I18n.t(msg_key, type: appeal.class.name.demodulize, id: appeal.id),
              status: '422',
              title: 'PDF download not ready'
            }
          ]
        }
      )
    end

    def render_pdf_download_expired(appeal)
      render(
        status: :gone,
        json: {
          errors: [
            {
              code: '410',
              detail: I18n.t(
                'appeals_api.errors.pdf_download_expired',
                type: appeal.class.name.demodulize,
                id: appeal.id
              ),
              status: '410',
              title: 'PDF download expired'
            }
          ]
        }
      )
    end
  end
end
