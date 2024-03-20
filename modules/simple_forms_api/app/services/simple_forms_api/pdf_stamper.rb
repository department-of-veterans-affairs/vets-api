# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module SimpleFormsApi
  class PdfStamper
    FORM_REQUIRES_STAMP = %w[26-4555 21-4142 21-10210 21-0845 21P-0847 21-0966 21-0972 20-10207 10-7959F-1].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at'
    SUBMISSION_DATE_TITLE = 'Application Submitted:'

    class << self
      def stamp_pdf(stamped_template_path, form, current_loa)
        instance = new(stamped_template_path, form, current_loa)
        form_number = form.data['form_number'].gsub('-', '').downcase

        instance.stamp if FORM_REQUIRES_STAMP.include? form_number

        current_time = Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S')
        stamp_text = "#{SUBMISSION_TEXT} #{current_time} "
        desired_stamps = [[10, 10, stamp_text]]
        verified_stamp(stamped_template_path, desired_stamps, instance.auth_text, text_only: false)

        stamp_submission_date(stamped_template_path, form.submission_date_config)
      end

      def stamp4010007_uuid(uuid)
        form = { data: { form_number: '4010007_uuid' } }
        instance = new('tmp/vba_40_10007-tmp.pdf', form, current_loa)
        instance.multistamp(instance.stamped_template_path, uuid, instance.page_configuration, 7, multiple: true)
      end

      def verified_stamp(stamped_template_path, *, multiple: false, **)
        orig_size = File.size(stamped_template_path)
        command = multiple ? 'multistamp' : 'stamp'
        send(command, stamped_template_path, *, **)
        stamped_size = File.size(stamped_template_path)

        raise StandardError, 'PDF stamping failed.' unless stamped_size > orig_size
      end

      def stamp(stamped_template_path, desired_stamps, append_to_stamp, text_only: true)
        current_file_path = stamped_template_path
        desired_stamps.each do |x, y, text|
          datestamp_instance = CentralMail::DatestampPdf.new(current_file_path, append_to_stamp:)
          current_file_path = datestamp_instance.run(text:, x:, y:, text_only:, size: 9)
        end
        File.rename(current_file_path, stamped_template_path)
      end

      def multistamp(stamped_template_path, signature_text, page_configuration, font_size = 16)
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

      def stamp_submission_date(stamped_template_path, config)
        if config[:should_stamp_date?]
          date_title_stamp_position = config[:title_coords]
          date_text_stamp_position = config[:text_coords]
          page_configuration = default_page_configuration
          page_configuration[config[:page_number]] = { type: :text, position: date_title_stamp_position }

          verified_stamp(stamped_template_path, SUBMISSION_DATE_TITLE, page_configuration, 12, multiple: true)

          page_configuration = default_page_configuration
          page_configuration[config[:page_number]] = { type: :text, position: date_text_stamp_position }

          current_time = Time.current.in_time_zone('UTC').strftime('%H:%M %Z %D')
          verified_stamp(stamped_template_path, current_time, page_configuration, 12, multiple: true)
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

    attr_accessor :auth_text

    def initialize(stamped_template_path, form, current_loa)
      @stamped_template_path = stamped_template_path
      @form = form
      @form_number = form.data['form_number'].gsub('-', '').downcase
      @auth_text = generate_auth_text(current_loa)
    end

    def stamp
      self.class.verified_stamp(stamped_template_path, desired_stamps[form_number], append_to_stamp)
    end

    def multistamp
      self.class.verified_stamp(stamped_template_path, signature_text, page_configuration, multiple: true)

      handle_214142_resubmit if form_number == '214142' && form.data['in_progress_form_created_at']
    end

    private

    attr_accessor :stamped_template_path, :form, :form_number

    def generate_auth_text(current_loa)
      case current_loa
      when 3
        'Signee signed with an identity-verified account.'
      when 2
        'Signee signed in but hasn’t verified their identity.'
      else
        'Signee not signed in.'
      end
    end

    def desired_stamps
      {
        default: build_default_stamps,
        '210845': [[50, 240]],
        '210966': [[50, 415]],
        '210972': [[50, 465]],
        '214142': [[50, 560]],
        '264555': build_264555_stamps,
        '2010207': build_2010207_stamps,
        '2110210': [[50, 160]],
        '107959f1': [[26, 82.5, signature_text]],
        '214142_date_title': [[440, 710]],
        '214142_date_text': [[440, 690]],
        '4010007_uuid': [[410, 20]]
      }
    end

    def page_configuration
      return self.class.default_page_configuration if form_number == 'default'

      new_page_count = {
        '2110210': { prepend: 2, append: 0 },
        '210845': { prepend: 2, append: 0 },
        '210972': { prepend: 2, append: 0 },
        '21p0847': { prepend: 1, append: 0 },
        '210966': { prepend: 1, append: 0 },
        '214142': { prepend: 1, append: 1 },
        '2010207': { prepend: 4, append: 0 },
        '214142_date_title': { prepend: 0, append: 2 },
        '214142_date_text': { prepend: 0, append: 2 },
        '4010007_uuid': { prepend: 0, append: 0 }
      }

      [].tap do |config|
        new_page_count[form_number][:prepend].times { config << { type: :new_page } }
        config << { type: :text, position: desired_stamps[form_number][0] }
        new_page_count[form_number][:append].times { config << { type: :new_page } }
      end
    end

    def append_to_stamp
      %w[107959f1 264555].exclude? form_number
    end

    def signature_text
      return unless %w[2110210 210845 21p0847 210972 210966 2010207 214142].include? form_number

      form.data['statement_of_truth_signature']
    end

    def build_default_stamps
      current_time = Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S')
      stamp_text = "#{SUBMISSION_TEXT} #{current_time} "
      [[10, 10, stamp_text]]
    end

    def build_264555_stamps
      [].tap do |desired_stamps|
        desired_stamps << [73, 390, 'X'] unless form.data['previous_sah_application']['has_previous_sah_application']
        desired_stamps << [73, 355, 'X'] unless form.data['previous_hi_application']['has_previous_hi_application']
        desired_stamps << [73, 320, 'X'] unless form.data['living_situation']['is_in_care_facility']
      end
    end

    def build_2010207_stamps
      if form.data['preparer_type'] == 'veteran'
        [[50, 690]]
      elsif form.data['third_party_type'] == 'power-of-attorney'
        [[50, 445]]
      elsif %w[third-party-veteran third-party-non-veteran non-veteran].include? form.data['preparer_type']
        [[50, 570]]
      end
    end

    def handle_214142_resubmit
      submissions = [
        { form_number: '214142_date_title', signature_text: self.class.SUBMISSION_DATE_TITLE },
        { form_number: '214142_date_text', signature_text: form.data['in_progress_form_created_at'] }
      ]
      submissions.each do |form_number, signature_text|
        @form_number = form_number
        self.class.verified_stamp(stamped_template_path, signature_text, page_configuration, 12, multiple: true)
      end
    end
  end
end
