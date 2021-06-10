# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for generating PDFs from questionnaire response snapshots
    #
    # @!attribute questionnaire_response
    #   @return [HealthQuest::QuestionnaireResponse]
    # @!attribute appointment
    #   @return [FHIR::ClientReply]
    # @!attribute location
    #   @return [FHIR::ClientReply]
    # @!attribute org
    #   @return [FHIR::ClientReply]
    # @!attribute style
    #   @return [HealthQuest::QuestionnaireManager::QuestionnaireResponseReportStyle]
    class QuestionnaireResponseReport
      include Prawn::View

      DATE_FORMAT = '%A, %B %d, %Y'
      QR_DATE_FORMAT = '%B %d, %Y.'
      HEADER_DATE_FORMAT = '%m/%d/%Y'
      TIME_FORMAT = '%-I:%M %p'
      TIME_ZONE_FORMAT = '%Z'
      DEFAULT_TIME_ZONE = 'Pacific Time (US & Canada)'
      VA_LOGO = 'modules/health_quest/app/assets/images/va_logo.png'
      VA_URL = 'https://va.gov/'

      attr_reader :questionnaire_response, :appointment, :location, :org, :style

      ##
      # Builds a HealthQuest::QuestionnaireManager::QuestionnaireResponseReport instance
      #
      # @param questionnaire_response [HealthQuest::QuestionnaireResponse]
      # @return [HealthQuest::QuestionnaireManager::QuestionnaireResponseReport] an instance of this class
      #
      def self.manufacture(opts = {})
        new(opts)
      end

      def initialize(opts)
        document.state.store.info.data = info

        @questionnaire_response = opts[:questionnaire_response]
        @appointment = opts[:appointment]
        @location = opts[:location]
        @org = opts[:org]
        @style = QuestionnaireResponseReportStyle.new

        build_content
      end

      def build_content
        set_font

        repeat(:all) do
          set_header
          set_footer
        end

        set_body
      end

      def set_font
        font_families.update(
          'HealthQuestPDF' => {
            normal: HealthQuest::Engine.root.join('lib', 'fonts', 'sourcesanspro-regular-webfont.ttf'),
            medium: HealthQuest::Engine.root.join('lib', 'fonts', 'sourcesanspro-bold-webfont.ttf'),
            bold: HealthQuest::Engine.root.join('lib', 'fonts', 'bitter-bold.ttf')
          }
        )
        font 'HealthQuestPDF'
      end

      def set_header
        bounding_box([0, bounds.top], width: bounds.width) do
          table(header_columns, style.header_style)

          set_logo
          move_down(24)

          table([[qr_data.dig('questionnaire', 'title')]], style.title_style)
          table([[org_name]], style.normal_text_style)
          move_down(24)
        end
      end

      def set_footer
        footer_text = "#{full_name} | Date of birth: #{date_of_birth}"

        bounding_box([0, bounds.bottom], width: bounds.width, height: 24) do
          text footer_text, size: 9, align: :center
        end
      end

      def set_logo
        image VA_LOGO, style.logo_style
      end

      def set_body
        bounding_box([0, bounds.top - 164], width: bounds.width, height: 545) do
          set_basic_appointment_info
          move_down(24)
          set_basic_demographics
          move_down(24)
          set_qr_header
          set_questionnaire_items
        end
      end

      def set_basic_appointment_info
        set_provider_info_text

        table(
          [['Date:', appointment_date],
           ['Time:', appointment_time],
           ['Location:', appointment_destination]], style.default_table_style
        ) do |table|
          table.column(1).font_style = :medium
        end
      end

      def set_basic_demographics
        table([['Veteran information']], style.heading_one_style)
        table((set_about + set_address + set_phone), style.default_table_style) do |table|
          table.column(1).font_style = :medium
        end
      end

      def set_about
        [
          ['Name:', full_name],
          ['Date of birth:', date_of_birth],
          ['Gender:', user_data['gender']]
        ]
      end

      def set_address
        [
          ['Country:', user_data&.dig('address', 'country')],
          ['Mailing address:', format_address(user_data['mailing_address'])],
          ['Home address:', format_address(user_data['home_address'])]
        ]
      end

      def format_address(addr)
        return if addr.blank?

        street_info = [addr['address_line1'], addr['address_line2'], addr['address_line3']].compact.join(' ')
        city = addr['city']
        state = addr['state_code']
        zip = addr['zip_code']

        "#{street_info}, #{city}, #{state} #{zip}"
      end

      def set_phone
        [
          ['Home phone:', format_phone(user_data['home_phone'])],
          ['Mobile phone:', format_phone(user_data['mobile_phone'])],
          ['Work phone:', format_phone(user_data['work_phone'])]
        ]
      end

      def format_phone(phone_hash)
        return if phone_hash.blank?

        area_code = phone_hash['area_code']
        prefix = phone_hash['phone_number']&.first(3)
        line = phone_hash['phone_number']&.last(4)

        [area_code, prefix, line].compact.join('-')
      end

      def set_questionnaire_items
        questions = questionnaire_response&.questionnaire_response_data&.fetch('item')

        questions.each do |q|
          answers = q['answer']

          table([[q['text'], '']], style.table_question_style)
          move_down(16)

          answers.each do |a|
            table([['', a['valueString']]], style.table_answer_style)
            move_down(10)
          end
        end
      end

      def set_provider_info_text
        table([["Your questionnaire was sent to your provider on #{qr_submitted_time}"]], style.heading_one_style)
        table([['Your provider will discuss the information on your questionnaire during your appointment:']],
              style.bold_text_style)
      end

      def qr_submitted_time
        questionnaire_response&.created_at&.in_time_zone(DEFAULT_TIME_ZONE)&.to_date&.strftime(QR_DATE_FORMAT)
      end

      def appointment_date
        time = DateTime.strptime(appt_utc_time)&.in_time_zone(DEFAULT_TIME_ZONE)

        time.strftime(DATE_FORMAT)
      end

      def appointment_time
        time = DateTime.strptime(appt_utc_time).in_time_zone(DEFAULT_TIME_ZONE)
        local_time = time.strftime(TIME_FORMAT)
        local_time_zone = time.strftime(TIME_ZONE_FORMAT)

        "#{local_time} #{local_time_zone}"
      end

      def appt_utc_time
        appointment&.resource&.start
      end

      def appointment_destination
        "#{loc_name}, #{org_name}"
      end

      def full_name
        "#{user_data['first_name']&.downcase&.capitalize} #{user_data['last_name']&.downcase&.capitalize}"
      end

      def date_of_birth
        DateTime.parse(user_data['date_of_birth'])&.strftime(HEADER_DATE_FORMAT)
      end

      def set_qr_header
        table([['Prepare for your visit']], style.heading_one_style)
        move_down(16)
      end

      def org_name
        org&.resource&.name
      end

      def loc_name
        location&.resource&.name
      end

      def header_columns
        [[today, VA_URL]]
      end

      def today
        DateTime.now.to_date.strftime(HEADER_DATE_FORMAT)
      end

      def user_data
        @user_data ||= questionnaire_response&.user_demographics_data
      end

      def qr_data
        @qr_data ||= questionnaire_response&.questionnaire_response_data
      end

      def info
        {
          Lang: 'en-us',
          Title: 'Primary Care Questionnaire',
          Author: 'Department of Veterans Affairs',
          Subject: 'Primary Care Questionnaire',
          Keywords: 'health questionnaires pre-visit',
          Creator: 'va.gov',
          Producer: 'va.gov',
          CreationDate: Time.zone.now
        }
      end
    end
  end
end
