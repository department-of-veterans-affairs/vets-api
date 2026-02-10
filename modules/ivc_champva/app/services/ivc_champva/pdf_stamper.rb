# frozen_string_literal: true

require 'pdf_utilities/datestamp_pdf'
require 'ivc_champva/monitor'

module IvcChampva
  class PdfStamper
    FORM_REQUIRES_STAMP = %w[10-10D 10-10D-EXTENDED 10-7959F-1 10-7959A 10-7959C].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '
    SUBMISSION_DATE_TITLE = 'Application Submitted:'

    # Constant dimensions for stamping on a blank page
    PAGE_HEIGHT = 792    # Total height of the blank page
    TOP_MARGIN = 20      # Top margin
    BOTTOM_MARGIN = 50   # Bottom margin where we'll stop adding content
    LINE_HEIGHT = 20     # Height of each metadata line
    LEFT_MARGIN = 25     # Left margin for text

    ##
    # Stamps a PDF with all necessary data
    #
    # @param stamped_template_path [String] Path and filename for the stamped template file
    # @param form [IvcChampva::Form] Form data
    # @param current_loa [Integer, nil] Current level of access
    # @return [void]
    def self.stamp_pdf(stamped_template_path, form, current_loa) # rubocop:disable Metrics/MethodLength
      if File.exist? stamped_template_path
        Rails.logger.info 'IVC Champva Forms - PdfStamper: stamping signature'
        stamp_signature(stamped_template_path, form)

        Rails.logger.info 'IVC Champva Forms - PdfStamper: stamping auth text'
        stamp_auth_text(stamped_template_path, current_loa)

        Rails.logger.info 'IVC Champva Forms - PdfStamper: stamping submission date'
        stamp_submission_date(stamped_template_path, form.submission_date_stamps)
      else
        Rails.logger.info 'IVC Champva Forms - PdfStamper: stamped_template_path does not exist, aborting'
        raise "stamped template file does not exist: #{stamped_template_path}"
      end
    rescue PdfForms::PdftkError => e
      file_regex = %r{/(?:\w+/)*[\w-]+\.pdf\b}
      password_regex = /(input_pw).*?(output)/
      sanitized_message = e.message.gsub(file_regex, '[FILTERED FILENAME]').gsub(password_regex, '\1 [FILTERED] \2')

      Rails.logger.error "IVC Champva Forms - PdfStamper: A pdftk error occurred: #{sanitized_message}"
      Rails.logger.error e.backtrace.join("\n")
      monitor.track_pdf_stamper_error(form.data['uuid'], "PdftkError: #{sanitized_message}")
      raise
    rescue SystemCallError => e
      # e.message could contain a filename and PII, so only pass on the decoded error number when available
      error_name = Errno.constants.find(proc {
        "Unknown #{e.errno}"
      }) { |c| Errno.const_get(c).new.errno == e.errno }.to_s

      Rails.logger.error "IVC Champva Forms - PdfStamper: A system call error occurred: #{error_name}"
      Rails.logger.error e.backtrace.join("\n")
      monitor.track_pdf_stamper_error(form.data['uuid'], "SystemCallError: #{error_name}")
      raise
    rescue => e
      Rails.logger.error "IVC Champva Forms - PdfStamper: An error occurred: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      monitor.track_pdf_stamper_error(form.data['uuid'], "CatchAll: #{e.message}")
      raise
    end

    ##
    # Applies all desired stamps only on forms that require stamps
    #
    # @param stamped_template_path [String] Path and filename for the stamped template file
    # @param form [IvcChampva::Form] Form data
    # @return [void]
    def self.stamp_signature(stamped_template_path, form)
      form_number = form.data['form_number']
      if FORM_REQUIRES_STAMP.include? form_number
        # multiple checks to ensure we only log in non-production environments - PII risk
        log_stamp_text = Flipper.enabled?(:champva_stamper_logging) && Settings.vsp_environment != 'production'

        form.desired_stamps.each do |desired_stamp|
          if log_stamp_text
            Rails.logger.info "IVC Champva Forms - PdfStamper: desired stamp text: #{desired_stamp[:text]}"
          end
          stamp(desired_stamp, stamped_template_path)
        end
      end
    end

    ##
    # Stamps the form with authentication text
    # @param stamped_template_path [String] Path and filename for the stamped template file
    # @param current_loa [Integer, nil] Current level of access
    # @return [void]
    def self.stamp_auth_text(stamped_template_path, current_loa)
      current_time = "#{Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S')} "
      auth_text = case current_loa
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
        stamp(desired_stamp, stamped_template_path, append_to_stamp: auth_text, text_only: false)
      end
    end

    # rubocop:disable Metrics/MethodLength
    def self.multistamp(stamped_template_path, signature_text, page_configuration, font_size = 16)
      Rails.logger.info 'IVC Champva Forms - PdfStamper: entered multistamp'
      stamp_path = Common::FileHelpers.random_file_path
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        page_configuration.each do |config|
          Rails.logger.info 'IVC Champva Forms - PdfStamper: multistamp processing page_configuration'
          case config[:type]
          when :text
            Rails.logger.info 'IVC Champva Forms - PdfStamper: multistamp drawing text'
            pdf.draw_text signature_text, at: config[:position], size: font_size
          when :new_page
            Rails.logger.info 'IVC Champva Forms - PdfStamper: multistamp starting new page'
            pdf.start_new_page
          end
        end
      end

      perform_multistamp(stamped_template_path, stamp_path)
    rescue => e
      Rails.logger.info 'IVC Champva Forms - PdfStamper: multistamp handling error'
      Rails.logger.error 'IVC Champva Forms - PdfStamper: Failed to generate stamped file', message: e.message
      Rails.logger.error e.backtrace.join("\n")
      Rails.logger.info 'IVC Champva Forms - PdfStamper: multistamp re-raising error'
      raise
    ensure
      begin
        Rails.logger.info 'IVC Champva Forms - PdfStamper: multistamp deleting temporary file in ensure block'
        Common::FileHelpers.delete_file_if_exists(stamp_path) if defined?(stamp_path)
      rescue => e
        Rails.logger.error 'IVC Champva Forms - PdfStamper: multistamp error in ensure block, logging and swallowing'
        Rails.logger.error 'IVC Champva Forms - PdfStamper: Failed to clean up temporary file', message: e.message
        Rails.logger.error e.backtrace.join("\n")
        # Don't re-raise an error here, the original error is more important
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def self.stamp(desired_stamp, stamped_template_path, append_to_stamp: false, text_only: true)
      Rails.logger.info 'IVC Champva Forms - PdfStamper: entered stamp'
      current_file_path = stamped_template_path
      coords = desired_stamp[:coords]
      text = desired_stamp[:text]
      page = desired_stamp[:page]
      font_size = desired_stamp[:font_size]
      x = coords[0]
      y = coords[1]
      if page
        page_configuration = get_page_configuration(page, coords)
        Rails.logger.info 'IVC Champva Forms - PdfStamper: stamp calling verified_multistamp'
        verified_multistamp(stamped_template_path, text, page_configuration, font_size)
      else
        begin
          Rails.logger.info 'IVC Champva Forms - PdfStamper: stamp creating datestamp instance'
          datestamp_instance = PDFUtilities::DatestampPdf.new(current_file_path, append_to_stamp:)
          current_file_path = datestamp_instance.run(text:, x:, y:, text_only:, size: 9)
          Rails.logger.info 'IVC Champva Forms - PdfStamper: stamp renaming to stamped_template_path'
          File.rename(current_file_path, stamped_template_path)
        rescue
          begin
            Rails.logger.info 'IVC Champva Forms - PdfStamper: stamp an error occurred, deleting temp file'
            Common::FileHelpers.delete_file_if_exists(current_file_path)
          rescue => e
            Rails.logger.error 'IVC Champva Forms - PdfStamper: stamp error in rescue, logging and swallowing'
            Rails.logger.error 'IVC Champva Forms - PdfStamper: Failed to clean up temporary file', message: e.message
            Rails.logger.error e.backtrace.join("\n")
            # Don't re-raise an error here, the original error is more important
          end
          Rails.logger.info 'IVC Champva Forms - PdfStamper: stamp re-raising error'
          raise
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def self.perform_multistamp(stamped_template_path, stamp_path)
      Rails.logger.info 'IVC Champva Forms - PdfStamper: entered perform_multistamp'
      out_path = "#{Common::FileHelpers.random_file_path}.pdf"
      pdftk = PdfFill::Filler::PDF_FORMS
      Rails.logger.info 'IVC Champva Forms - PdfStamper: perform_multistamp calling pdftk.multistamp'
      pdftk.multistamp(stamped_template_path, stamp_path, out_path)
      Rails.logger.info 'IVC Champva Forms - PdfStamper: perform_multistamp post pdftk.multistamp delete'
      File.delete(stamped_template_path)
      Rails.logger.info 'IVC Champva Forms - PdfStamper: perform_multistamp post pdftk.multistamp rename'
      File.rename(out_path, stamped_template_path)
    rescue
      begin
        Rails.logger.info 'IVC Champva Forms - PdfStamper: perform_multistamp an error occurred, deleting temp file'
        Common::FileHelpers.delete_file_if_exists(out_path)
      rescue => e
        Rails.logger.error 'IVC Champva Forms - PdfStamper: perform_multistamp error in rescue, logging and swallowing'
        Rails.logger.error 'IVC Champva Forms - PdfStamper: Failed to clean up temporary file', message: e.message
        Rails.logger.error e.backtrace.join("\n")
        # Don't re-raise an error here, the original error is more important
      end
      Rails.logger.info 'IVC Champva Forms - PdfStamper: perform_multistamp re-raising error'
      raise
    end

    ##
    # Stamps the forms with everything in desired_stamps
    #
    # @param stamped_template_path [String] Path and filename for the stamped template file
    # @param desired_stamps [Array<Hash>] Array of hashes containing stamp data
    # @return [void]
    def self.stamp_submission_date(stamped_template_path, desired_stamps)
      if desired_stamps.is_a?(Array)
        desired_stamps.each do |desired_stamp|
          stamp(desired_stamp, stamped_template_path)
        end
      end
    end

    def self.verify(template_path)
      orig_size = File.size(template_path)
      yield
      stamped_size = File.size(template_path)

      raise StandardError, 'The PDF remained unchanged upon stamping.' unless stamped_size > orig_size
    rescue Prawn::Errors::IncompatibleStringEncoding
      Rails.logger.info 'IVC Champva Forms - PdfStamper: error on verify, incompatible string encoding, re-raising'
      raise
    rescue => e
      Rails.logger.info 'IVC Champva Forms - PdfStamper: error on verify, catch all, wrapping in a new standard error'
      raise StandardError, "An error occurred while verifying stamp: #{e}"
    end

    def self.verified_multistamp(stamped_template_path, stamp_text, page_configuration, *)
      raise StandardError, 'The provided stamp content was empty.' if stamp_text.blank?

      verify(stamped_template_path) { multistamp(stamped_template_path, stamp_text, page_configuration, *) }
    end

    def self.get_page_configuration(page, position)
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

    ##
    # Stamps metadata items on a PDF document at specified coordinates.
    #
    # @param pdf_path [String] The file path to the PDF document to be stamped
    # @param metadata [Hash] A hash containing key-value pairs to be stamped on the PDF
    # @param start_y [Integer] The starting Y-coordinate position for the first metadata item
    # @param page_number [Integer] The page number on which to stamp the metadata
    #
    # @return [Array<Array, Hash>] A tuple containing:
    #   - An array of keys that were successfully stamped
    #   - A hash of remaining metadata items that couldn't be stamped (due to space constraints)
    #
    # @example
    #   stamped, remaining = stamp_metadata_items('path/to/file.pdf', {'name' => 'John Doe'}, 700, 1)
    #
    # @note This method will stop stamping when it reaches the bottom margin defined by BOTTOM_MARGIN
    #       and will return any unstamped metadata items
    def self.stamp_metadata_items(pdf_path, metadata, start_y = PAGE_HEIGHT, page_number = 0)
      y_position = start_y
      already_stamped = []

      metadata.each do |key, value|
        # If we hit the bottom margin, return what's left to process
        return [already_stamped, metadata.except(*already_stamped)] if y_position < BOTTOM_MARGIN

        # Format and stamp the metadata text
        text = "#{key.humanize}: #{value}"
        y_position -= LINE_HEIGHT
        desired_stamp = { coords: [LEFT_MARGIN, y_position], text:, page: page_number }

        stamp(desired_stamp, pdf_path)
        already_stamped << key
      end

      # All items stamped successfully
      [already_stamped, {}]
    end

    ##
    # retreive a monitor for tracking
    #
    # @return [IvcChampva::Monitor]
    #
    def self.monitor
      IvcChampva::Monitor.new
    end
  end
end
