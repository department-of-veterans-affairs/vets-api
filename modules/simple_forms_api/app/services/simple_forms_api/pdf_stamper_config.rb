# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module SimpleFormsApi
  class PdfStamperConfig
    class << self
      def generate_config(stamped_template_path, form, current_loa)
        new(stamped_template_path, form, current_loa).to_h
      end

      def generate_stamps(form_number)
        form = OpenStruct.new(data: { form_number: })
        new(nil, form, nil).stamps
      end
    end

    attr_accessor :stamps

    def initialize(stamped_template_path, form, current_loa)
      @template_path = stamped_template_path
      @form = form
      @current_loa = current_loa
      @form_number = form.data.stringify_keys['form_number'].gsub('-', '').downcase.to_sym
      @stamps = desired_stamps[form_number] || build_default_stamps
      @font_size = FONT_SIZES[form_number] || 16
    end

    def to_h
      {
        append_to_stamp:,
        font_size:,
        form_number:,
        form:,
        multistamp:,
        page_config:,
        signature_text:,
        stamps:,
        template_path:
      }
    end

    private

    attr_accessor :form, :form_number, :template_path, :font_size

    PAGE_CONFIGURATIONS = {
      '2110210': { page_count: 3, page_index: 2 },
      '210845': { page_count: 3, page_index: 2 },
      '210972': { page_count: 3, page_index: 2 },
      '21p0847': { page_count: 2, page_index: 1 },
      '210966': { page_count: 2, page_index: 1 },
      '214142': { page_count: 3, page_index: 1 },
      '2010207': { page_count: 5, page_index: 4 },
      '214142_date_title': { page_count: 3, page_index: 0 },
      '214142_date_text': { page_count: 3, page_index: 0 },
      '4010007_uuid': { page_count: 1, page_index: 0 }
    }.freeze

    FONT_SIZES = {
      '214142_date_title': 12,
      '214142_date_text': 12,
      '4010007_uuid': 7
    }.freeze

    def append_to_stamp
      return false if %w[107959f1 264555].include? form_number

      case @current_loa
      when 3
        'Signee signed with an identity-verified account.'
      when 2
        'Signee signed in but hasn’t verified their identity.'
      else
        'Signee not signed in.'
      end
    end

    def signature_text
      return unless %w[2110210 210845 21p0847 210972 210966 2010207 214142].include? form_number

      form.data['statement_of_truth_signature']
    end

    def desired_stamps
      {
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

    def page_config
      return default_page_configuration unless PAGE_CONFIGURATIONS[form_number]

      page_data = PAGE_CONFIGURATIONS[form_number]

      @page_config ||= [].tap do |config|
        page_data[:page_count].times { config << { type: :new_page } }
        config[page_data[:page_index]] = { type: :text, position: stamps&.dig(0) }
      end
    end

    def multistamp
      %w[107959f1 264555].exclude? form_number
    end

    def build_default_stamps
      current_time = Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S')
      stamp_text = "#{PdfStamper::SUBMISSION_TEXT} #{current_time} "
      [[10, 10, stamp_text]]
    end

    def build_264555_stamps
      return [] unless form.data

      [].tap do |stamps|
        stamps << [73, 390, 'X'] unless form.data.dig('previous_sah_application', 'has_previous_sah_application')
        stamps << [73, 355, 'X'] unless form.data.dig('previous_hi_application', 'has_previous_hi_application')
        stamps << [73, 320, 'X'] unless form.data.dig('living_situation', 'is_in_care_facility')
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
