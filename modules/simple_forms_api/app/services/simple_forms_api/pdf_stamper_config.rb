# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module SimpleFormsApi
  class PdfStamperConfig
    PAGE_CONFIGS = {
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
    }.freeze

    attr_accessor :auth_text, :form_number, :stamps, :page_config, :template_path

    def initialize(stamped_template_path, form, current_loa)
      @template_path = stamped_template_path
      @form = form
      @form_number = form.data['form_number'].gsub('-', '').downcase.to_sym
      @stamps = desired_stamps[form_number]
      @page_config = generate_page_configuration
      @auth_text = generate_auth_text(current_loa)
    end

    def stamp
      PdfStamper.verified_stamp(template_path, stamps, append_to_stamp)
    end

    def multistamp
      PdfStamper.verified_stamp(template_path, signature_text, page_config, multiple: true)

      handle_214142_resubmit if form_number == '214142' && form.data['in_progress_form_created_at']
    end

    private

    attr_accessor :form

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

    def generate_page_configuration
      return default_page_configuration if form_number == 'default'

      return unless PAGE_CONFIGS[form_number]

      [].tap do |config|
        PAGE_CONFIGS[form_number][:prepend].times { config << { type: :new_page } }
        config << { type: :text, position: stamps&.dig(0) }
        PAGE_CONFIGS[form_number][:append].times { config << { type: :new_page } }
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
      stamp_text = "#{PdfStamper::SUBMISSION_TEXT} #{current_time} "
      [[10, 10, stamp_text]]
    end

    def build_264555_stamps
      return [] unless form.data

      [].tap do |desired_stamps|
        desired_stamps << [73, 390, 'X'] unless form.data.dig('previous_sah_application', 'has_previous_sah_application')
        desired_stamps << [73, 355, 'X'] unless form.data.dig('previous_hi_application', 'has_previous_hi_application')
        desired_stamps << [73, 320, 'X'] unless form.data.dig('living_situation', 'is_in_care_facility')
      end
    end

    def build_2010207_stamps
      return [] unless form.data

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
        { form_number: '214142_date_title', signature_text: PdfStamper.SUBMISSION_DATE_TITLE },
        { form_number: '214142_date_text', signature_text: form.data['in_progress_form_created_at'] }
      ]
      submissions.each do |form_number, signature_text|
        @form_number = form_number
        PdfStamper.verified_stamp(template_path, signature_text, page_config, 12, multiple: true)
      end
    end
  end
end
