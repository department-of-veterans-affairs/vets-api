# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module IvcChampva
  class PdfStamper
    FORM_REQUIRES_STAMP = %w[10-7959F-1].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '
    SUBMISSION_DATE_TITLE = 'Application Submitted:'

    def self.stamp_pdf(stamped_template_path, form, current_loa)
      form_number = form.data['form_number']
      if FORM_REQUIRES_STAMP.include? form_number
        stamp_method = "stamp#{form_number.gsub('-', '')}".downcase
        send(stamp_method, stamped_template_path, form)
      end

      current_time = "#{Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S')} "
      auth_text = case current_loa
                  when 3
                    'Signee signed with an identity-verified account.'
                  when 2
                    'Signee signed in but hasn’t verified their identity.'
                  else
                    'Signee not signed in.'
                  end
      stamp_text = SUBMISSION_TEXT + current_time
      desired_stamps = [[10, 10, stamp_text]]
      verify(stamped_template_path) { stamp(desired_stamps, stamped_template_path, auth_text, text_only: false) }

      stamp_submission_date(stamped_template_path, form.submission_date_config)
    end

    def self.stamp107959f1(stamped_template_path, form)
      desired_stamps = [[26, 82.5, form.data['statement_of_truth_signature']]]
      append_to_stamp = false
      verify(stamped_template_path) { stamp(desired_stamps, stamped_template_path, append_to_stamp) }
    end

    def self.multistamp(stamped_template_path, signature_text, page_configuration, font_size = 16)
      stamp_path = Common::FileHelpers.random_file_path
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

    def self.stamp(desired_stamps, stamped_template_path, append_to_stamp, text_only: true)
      current_file_path = stamped_template_path
      desired_stamps.each do |x, y, text|
        datestamp_instance = CentralMail::DatestampPdf.new(current_file_path, append_to_stamp:)
        current_file_path = datestamp_instance.run(text:, x:, y:, text_only:, size: 9)
      end
      File.rename(current_file_path, stamped_template_path)
    end

    def self.perform_multistamp(stamped_template_path, stamp_path)
      out_path = "#{Common::FileHelpers.random_file_path}.pdf"
      pdftk = PdfFill::Filler::PDF_FORMS
      pdftk.multistamp(stamped_template_path, stamp_path, out_path)
      File.delete(stamped_template_path)
      File.rename(out_path, stamped_template_path)
    rescue
      Common::FileHelpers.delete_file_if_exists(out_path)
      raise
    end

    def self.stamp_submission_date(stamped_template_path, config)
      if config[:should_stamp_date?]
        date_title_stamp_position = config[:title_coords]
        date_text_stamp_position = config[:text_coords]
        page_configuration = default_page_configuration
        page_configuration[config[:page_number]] = { type: :text, position: date_title_stamp_position }

        verified_multistamp(stamped_template_path, SUBMISSION_DATE_TITLE, page_configuration, 12)

        page_configuration = default_page_configuration
        page_configuration[config[:page_number]] = { type: :text, position: date_text_stamp_position }

        current_time = Time.current.in_time_zone('UTC').strftime('%H:%M %Z %D')
        verified_multistamp(stamped_template_path, current_time, page_configuration, 12)
      end
    end

    def self.verify(template_path)
      orig_size = File.size(template_path)
      yield
      stamped_size = File.size(template_path)

      raise StandardError, 'The PDF remained unchanged upon stamping.' unless stamped_size > orig_size
    rescue => e
      raise StandardError, "An error occurred while verifying stamp: #{e}"
    end

    def self.verified_multistamp(stamped_template_path, stamp_text, page_configuration, *)
      raise StandardError, 'The provided stamp content was empty.' if stamp_text.blank?

      verify(stamped_template_path) { multistamp(stamped_template_path, stamp_text, page_configuration, *) }
    end

    def self.default_page_configuration
      [
        { type: :new_page },
        { type: :new_page },
        { type: :new_page },
        { type: :new_page }
      ]
    end
  end
end
