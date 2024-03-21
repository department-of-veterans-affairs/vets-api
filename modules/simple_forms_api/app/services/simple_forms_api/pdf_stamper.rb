# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module SimpleFormsApi
  class PdfStamper
    FORM_REQUIRES_STAMP = %w[26-4555 21-4142 21-10210 21-0845 21P-0847 21-0966 21-0972 20-10207 10-7959F-1].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at'
    SUBMISSION_DATE_TITLE = 'Application Submitted:'

    class << self
      def stamp_pdf(stamped_template_path, form, current_loa)
        config = PdfStamperConfig.generate_config(stamped_template_path, form, current_loa)

        verified_stamp(config) if FORM_REQUIRES_STAMP.include? config[:form_number]
        handle_214142_resubmit(config) if config[:form_number] == '214142' && form.data['in_progress_form_created_at']

        form.data['form_number'] = 'default'
        default_config = PdfStamperConfig.generate_config(stamped_template_path, form, current_loa)
        verified_stamp(**default_config)

        stamp_submission_date(config[:template_path], form.submission_date_config)
      end

      def stamp4010007_uuid(uuid)
        form = OpenStruct.new(data: { form_number: '4010007_uuid' })
        config = PdfStamperConfig.generate_config('tmp/vba_40_10007-tmp.pdf', form, current_loa)
        verified_stamp(config.template_path, uuid, config.page_config, 7, multistamp: config.multistamp)
      end

      private

      def verified_stamp(template_path:, multistamp:, **)
        orig_size = File.size(template_path)
        command = multistamp ? 'multistamp' : 'stamp'
        send(command, template_path:, **)
        stamped_size = File.size(template_path)

        raise StandardError, 'PDF stamping failed.' unless stamped_size > orig_size
      end

      def stamp(template_path:, stamps:, append_to_stamp:, text_only: true, **)
        current_file_path = template_path
        stamps.each do |x, y, text|
          datestamp_instance = CentralMail::DatestampPdf.new(current_file_path, append_to_stamp:)
          current_file_path = datestamp_instance.run(text:, x:, y:, text_only:, size: 9)
        end
        File.rename(current_file_path, template_path)
      end

      def multistamp(template_path:, signature_text:, page_config:, font_size: 16, **)
        stamp_path = Common::FileHelpers.random_file_path
        Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
          page_config.each do |config|
            case config[:type]
            when :text
              pdf.draw_text signature_text, at: config[:position], size: font_size
            when :new_page
              pdf.start_new_page
            end
          end
        end

        perform_multistamp(template_path, stamp_path)
      rescue => e
        Rails.logger.error 'Simple forms api - Failed to generate stamped file', message: e.message
        raise
      ensure
        Common::FileHelpers.delete_file_if_exists(stamp_path) if defined?(stamp_path)
      end

      def perform_multistamp(stamped_template_path, stamp_path)
        out_path = "#{Common::FileHelpers.random_file_path}.pdf"
        pdftk = PdfFill::Filler::PDF_FORMS
        pdftk.multistamp(stamped_template_path, stamp_path, out_path)
        File.delete(stamped_template_path)
        File.rename(out_path, stamped_template_path)
      rescue
        Common::FileHelpers.delete_file_if_exists(out_path)
        raise
      end

      def stamp_submission_date(template_path, config)
        if config[:should_stamp_date?]
          date_title_stamp_position = config[:title_coords]
          page_config = default_page_configuration
          page_config[config[:page_number]] = { type: :text, position: date_title_stamp_position }
          signature_text = SUBMISSION_DATE_TITLE

          verified_stamp(template_path:, signature_text:, page_config:, font_size: 12, multistamp: true)

          date_text_stamp_position = config[:text_coords]
          page_config = default_page_configuration
          page_config[config[:page_number]] = { type: :text, position: date_text_stamp_position }
          signature_text = Time.current.in_time_zone('UTC').strftime('%H:%M %Z %D')

          verified_stamp(template_path:, signature_text:, page_config:, font_size: 12, multistamp: true)
        end
      end

      def handle_214142_resubmit(template_path:, current_loa:, **)
        submissions = [
          { form_number: '214142_date_title', signature_text: PdfStamper.SUBMISSION_DATE_TITLE },
          { form_number: '214142_date_text', signature_text: form.data['in_progress_form_created_at'] }
        ]
        submissions.each do |form_number, signature_text|
          form = OpenStruct.new(data: { form_number: })
          config = PdfStamperConfig.generate_config(template_path, form, current_loa)
          config[:signature_text] = signature_text
          verified_stamp(config)
        end
      end

      def default_page_configuration
        [
          { type: :new_page },
          { type: :new_page },
          { type: :new_page },
          { type: :new_page }
        ]
      end
    end
  end
end
