# frozen_string_literal: true

require 'pdf_utilities/datestamp_pdf'

module SimpleFormsApi
  class PdfStamper
    attr_reader :stamped_template_path, :form, :loa

    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '
    SUBMISSION_DATE_TITLE = 'Application Submitted:'

    def initialize(stamped_template_path, form, loa = nil)
      @stamped_template_path = stamped_template_path
      @form = form
      @loa = loa
    end

    def stamp_pdf
      all_form_stamps.each do |desired_stamp|
        if desired_stamp[:page]
          stamp_specified_page(desired_stamp, stamped_template_path)
        else
          stamp_all_pages(desired_stamp, stamped_template_path)
        end
      end

      stamp_auth_text
    rescue => e
      raise StandardError, "An error occurred while stamping the PDF: #{e}"
    end

    def self.stamp4010007_uuid(uuid)
      uuid = "UUID: #{uuid}"
      stamped_template_path = 'tmp/vba_40_10007-tmp.pdf'
      desired_stamps = [[390, 18]]
      page_configuration = [
        { type: :text, position: desired_stamps[0] }
      ]

      verified_multistamp(stamped_template_path, uuid, page_configuration, 9)
    end

    private

    def all_form_stamps
      form.desired_stamps + form.submission_date_stamps
    end

    def stamp_specified_page(desired_stamp, stamped_template_path)
      page_configuration = get_page_configuration(desired_stamp[:page], desired_stamp[:coords])
      verified_multistamp(stamped_template_path, desired_stamp[:text], page_configuration, desired_stamp[:font_size])
    end

    def stamp_all_pages(desired_stamp, stamped_template_path, append_to_stamp: nil)
      current_file_path = stamped_template_path
      Rails.logger.info('Calling PDFUtilities::DatestampPdf', current_file_path:, stamped_template_path:)
      datestamp_instance = PDFUtilities::DatestampPdf.new(current_file_path, append_to_stamp:)
      coords = desired_stamp[:coords]
      current_file_path = datestamp_instance.run(text: desired_stamp[:text], x: coords[0], y: coords[1],
                                                 text_only: true, size: 9)
      File.rename(current_file_path, stamped_template_path)
    end

    def stamp_auth_text
      current_time = "#{Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S')} "
      auth_text = case loa
                  when 3
                    'Signee signed with an identity-verified account.'
                  when 2
                    'Signee signed in but hasn’t verified their identity.'
                  else
                    'Signee not signed in.'
                  end
      coords = [10, 10]
      text = SUBMISSION_TEXT + current_time
      desired_stamp = { coords:, text: }
      verify(stamped_template_path) do
        stamp_all_pages(desired_stamp, stamped_template_path, append_to_stamp: auth_text)
      end
    end

    def verified_multistamp(stamped_template_path, stamp_text, page_configuration, *)
      raise StandardError, 'The provided stamp content was empty.' if stamp_text.blank?

      verify(stamped_template_path) { multistamp(stamped_template_path, stamp_text, page_configuration, *) }
    end

    def multistamp(stamped_template_path, signature_text, page_configuration, font_size = 16)
      stamp_path = Rails.root.join(Common::FileHelpers.random_file_path)
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        page_configuration.each do |config|
          case config[:type]
          when :text
            pdf.draw_text signature_text, at: config[:position], size: font_size
          when :new_page
            pdf.start_new_page
          end
        end
      end

      perform_multistamp(stamped_template_path, stamp_path)
    rescue => e
      Rails.logger.error 'Simple forms api - Failed to generate stamped file', message: e.message
      raise
    ensure
      Common::FileHelpers.delete_file_if_exists(stamp_path) if defined?(stamp_path)
    end

    def perform_multistamp(stamped_template_path, stamp_path)
      out_path = Rails.root.join("#{Common::FileHelpers.random_file_path}.pdf")
      pdftk = PdfFill::Filler::PDF_FORMS
      pdftk.multistamp(stamped_template_path, stamp_path, out_path)
      Common::FileHelpers.delete_file_if_exists(stamped_template_path)
      File.rename(out_path, stamped_template_path)
    rescue => e
      Rails.logger.error 'Simple forms api - Failed to perform multistamp', message: e.message
      Common::FileHelpers.delete_file_if_exists(out_path)
      raise e
    end

    def verify(template_path)
      orig_size = File.size(template_path)
      yield
      stamped_size = File.size(template_path)

      raise StandardError, 'The PDF remained unchanged upon stamping.' unless stamped_size > orig_size
    rescue Prawn::Errors::IncompatibleStringEncoding
      raise
    rescue => e
      raise StandardError, "An error occurred while verifying stamp: #{e}"
    end

    def get_page_configuration(page, position)
      [
        { type: :new_page },
        { type: :new_page },
        { type: :new_page },
        { type: :new_page },
        { type: :new_page }
      ].tap do |config|
        config[page] = { type: :text, position: }
      end
    end
  end
end
