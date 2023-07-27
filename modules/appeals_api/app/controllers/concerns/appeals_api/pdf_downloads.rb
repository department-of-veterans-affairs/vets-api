# frozen_string_literal: true

require 'common/file_helpers'
require 'pdf_fill/filler'

# rubocop:disable Metrics/ModuleLength
module AppealsApi
  module PdfDownloads
    extend ActiveSupport::Concern

    included do
      def render_appeal_pdf_download(appeal, filename)
        if expired?(appeal)
          # If the veteran_icn is available, we can check it against the current request's ICN header to return a 404
          # if it does not match, but otherwise, without auth_headers, we can't tell whether the current request is
          # authorized, so in that case we return a specific error message regardless of authorization status.
          if appeal.veteran_icn && appeal.veteran_icn != request.headers['X-VA-ICN']
            raise ActiveRecord::RecordNotFound
          else
            return render_pdf_download_expired(appeal)
          end
        end

        # We choose to return a 404 when PII in headers doesn't match the Appeal's PII so that we don't reveal the
        # existence of records that the user can't access
        raise ActiveRecord::RecordNotFound unless download_authorized?(appeal)

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

    # Determines whether the current request's headers authorize an appeal PDF download based on
    # X-VA-ICN, X-VA-File-Number, and the appeal's saved headers.
    def download_authorized?(appeal)
      return false unless (header_icn = request.headers['X-VA-ICN'])

      if appeal.veteran_icn.present?
        appeal.veteran_icn == header_icn
      elsif (appeal_icn = appeal.auth_headers['X-VA-ICN'])
        appeal_icn == header_icn
      elsif (appeal_ssn = appeal.auth_headers['X-VA-SSN'])
        appeal_ssn == MPI::Service.new.find_profile_by_identifier(
          identifier: header_icn,
          identifier_type: 'ICN'
        ).profile&.ssn
      elsif (appeal_file_number = appeal.auth_headers['X-VA-File-Number']) &&
            (header_file_number = request.headers['X-VA-File-Number'])
        appeal_file_number == header_file_number
      else
        false
      end
    end

    def submitted?(appeal)
      UNSUBMITTED_STATUSES.exclude?(appeal.status) && appeal.pdf_version.present?
    end

    def expired?(appeal)
      appeal.class.pii_expunge_policy.exists?(appeal.id) || appeal.auth_headers.blank?
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
# rubocop:enable Metrics/ModuleLength
