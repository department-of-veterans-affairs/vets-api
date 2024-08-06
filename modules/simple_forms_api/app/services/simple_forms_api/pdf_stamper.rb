# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module SimpleFormsApi
  class PdfStamper
    FORM_REQUIRES_STAMP = %w[20-10207 21-0845 21-0966 21-0972 21-4138 21-10210 21-4142 21P-0847 26-4555].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '
    SUBMISSION_DATE_TITLE = 'Application Submitted:'

    def self.stamp_pdf(stamped_template_path, form, current_loa)
      stamp_signature(stamped_template_path, form)

      stamp_auth_text(stamped_template_path, current_loa)

      stamp_submission_date(stamped_template_path, form.submission_date_stamps)
    end

    def self.stamp_signature(stamped_template_path, form)
      form_number = form.data['form_number']
      if FORM_REQUIRES_STAMP.include? form_number
        form.desired_stamps.each do |desired_stamp|
          stamp(desired_stamp, stamped_template_path)
        end
      end
    end

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

    def self.stamp4010007_uuid(uuid)
      uuid = "UUID: #{uuid}"
      stamped_template_path = 'tmp/vba_40_10007-tmp.pdf'
      desired_stamps = [[390, 18]]
      page_configuration = [
        { type: :text, position: desired_stamps[0] }
      ]

      verified_multistamp(stamped_template_path, uuid, page_configuration, 9)
    end

    def self.multistamp(stamped_template_path, signature_text, page_configuration, font_size = 16)
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

    def self.stamp(desired_stamp, stamped_template_path, append_to_stamp: false, text_only: true)
      current_file_path = stamped_template_path
      coords = desired_stamp[:coords]
      text = desired_stamp[:text]
      page = desired_stamp[:page]
      font_size = desired_stamp[:font_size]
      x = coords[0]
      y = coords[1]
      if page
        page_configuration = get_page_configuration(page, coords)
        verified_multistamp(stamped_template_path, text, page_configuration, font_size)
      else
        Rails.logger.info('Calling CentralMail::DatestampPdf', current_file_path:, stamped_template_path:)
        datestamp_instance = CentralMail::DatestampPdf.new(current_file_path, append_to_stamp:)
        current_file_path = datestamp_instance.run(text:, x:, y:, text_only:, size: 9)
        File.rename(current_file_path, stamped_template_path)
      end
    rescue => e
      raise StandardError, "An error occurred while stamping the PDF: #{e}"
    end

    def self.perform_multistamp(stamped_template_path, stamp_path)
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

    def self.stamp_submission_date(stamped_template_path, desired_stamps)
      desired_stamps.each do |desired_stamp|
        stamp(desired_stamp, stamped_template_path)
      end
    end

    def self.verify(template_path)
      orig_size = File.size(template_path)
      yield
      stamped_size = File.size(template_path)

      raise StandardError, 'The PDF remained unchanged upon stamping.' unless stamped_size > orig_size
    rescue Prawn::Errors::IncompatibleStringEncoding
      raise
    rescue => e
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
  end
end
