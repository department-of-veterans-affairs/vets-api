# frozen_string_literal: true

require 'pdf_utilities/datestamp_pdf'

module SimpleFormsApi
  class PdfStamper
    attr_reader :stamped_template_path, :form, :loa, :timestamp

    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '
    FORM_UPLOAD_SUBMISSION_TEXT = 'Submitted via VA.gov at '

    def initialize(stamped_template_path:, form: nil, current_loa: nil, timestamp: nil)
      @stamped_template_path = stamped_template_path
      @form = form
      @loa = current_loa
      @timestamp = timestamp
    end

    def stamp_pdf
      all_form_stamps.each do |desired_stamp|
        stamp_form(desired_stamp)
      end

      # Stamp the text which specifies the user's auth level (footer)
      verify { stamp_all_pages(get_auth_text_stamp, append_to_stamp: auth_text) }
    rescue => e
      raise StandardError, "An error occurred while stamping the PDF: #{e}"
    end

    def stamp_uuid(uuid)
      if form.instance_of? SimpleFormsApi::VBA4010007
        desired_stamp = { text: "UUID: #{uuid}", font_size: 9 }
        desired_stamps = [[390, 18]]
        page_configuration = [
          { type: :text, position: desired_stamps[0] }
        ]

        verified_multistamp(desired_stamp, page_configuration)
      end
    end

    private

    def pdftk
      @pdftk ||= PdfFill::Filler::PDF_FORMS
    end

    def all_form_stamps
      form ? form.desired_stamps + form.submission_date_stamps(timestamp) : []
    end

    def stamp_form(desired_stamp)
      if desired_stamp[:page]
        stamp_specified_page(desired_stamp)
      else
        stamp_all_pages(desired_stamp)
      end
    end

    def stamp_specified_page(desired_stamp)
      page_configuration = get_page_configuration(desired_stamp)
      verified_multistamp(desired_stamp, page_configuration)
    end

    def stamp_all_pages(desired_stamp, append_to_stamp: nil)
      current_file_path = call_datestamp_pdf(desired_stamp[:coords], desired_stamp[:text], append_to_stamp)
      File.rename(current_file_path, stamped_template_path)
    end

    def verified_multistamp(stamp, page_configuration)
      raise StandardError, 'The provided stamp content was empty.' if stamp[:text].blank?

      verify { multistamp(stamp, page_configuration) }
    end

    def multistamp(stamp, page_configuration)
      stamp_path = generate_prawn_document(stamp, page_configuration)
      perform_multistamp(stamp_path)
    rescue => e
      Rails.logger.error 'Simple forms api - Failed to generate stamped file', message: e.message
      raise
    ensure
      Common::FileHelpers.delete_file_if_exists(stamp_path) if defined?(stamp_path)
    end

    def perform_multistamp(stamp_path)
      out_path = Rails.root.join("#{Common::FileHelpers.random_file_path}.pdf")
      pdftk.multistamp(stamped_template_path, stamp_path, out_path)
      multistamp_cleanup(out_path)
    rescue => e
      handle_multistamp_error(e)
    end

    def multistamp_cleanup(out_path)
      Common::FileHelpers.delete_file_if_exists(stamped_template_path)
      File.rename(out_path, stamped_template_path)
    end

    def verify
      orig_size = File.size(stamped_template_path)
      yield
      stamped_size = File.size(stamped_template_path)

      raise StandardError, 'The PDF remained unchanged upon stamping.' unless stamped_size > orig_size
    rescue => e
      raise StandardError, "An error occurred while verifying stamp: #{e}"
    end

    def get_page_configuration(stamp)
      page = stamp[:page]
      position = stamp[:coords]
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

    def generate_prawn_document(stamp, page_configuration)
      stamp_path = Rails.root.join(Common::FileHelpers.random_file_path)
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        draw_text(pdf, stamp, page_configuration)
      end
      stamp_path
    end

    def draw_text(pdf, stamp, page_configuration)
      page_configuration.each do |config|
        case config[:type]
        when :text
          pdf.draw_text stamp[:text], at: config[:position], size: stamp[:font_size] || 16
        when :new_page
          pdf.start_new_page
        end
      end
    end

    def call_datestamp_pdf(coords, text, append_to_stamp)
      Rails.logger.info('Calling PDFUtilities::DatestampPdf', stamped_template_path:)
      text_only = append_to_stamp ? false : true
      datestamp_instance = PDFUtilities::DatestampPdf.new(stamped_template_path, append_to_stamp:)
      datestamp_instance.run(text:, x: coords[0], y: coords[1], text_only:, size: 9, timestamp:)
    end

    def get_auth_text_stamp
      current_time = "#{Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S')} "
      coords = [10, 10]
      submission_text = form ? SUBMISSION_TEXT : FORM_UPLOAD_SUBMISSION_TEXT
      text = submission_text + current_time
      { coords:, text: }
    end

    def auth_text
      if form
        case loa
        when 3
          'Signee signed with an identity-verified account.'
        when 2
          'Signee signed in but hasn’t verified their identity.'
        else
          'Signee not signed in.'
        end
      else
        case loa
        when 3
          'Signed in and submitted with an identity-verified account.'
        when 2
          'Signed in and submitted but has not verified their identity.'
        else
          'Signee not signed in.'
        end
      end
    end

    def handle_multistamp_error(e)
      Rails.logger.error 'Simple forms api - Failed to perform multistamp', message: e.message
      Common::FileHelpers.delete_file_if_exists(out_path)
      raise e
    end
  end
end
