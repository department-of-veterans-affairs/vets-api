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
        font 'Helvetica'
      end

      def set_header
        bounding_box([0, bounds.top], width: 520) do
          table(header_columns, style.header_style)

          set_logo

          table([[qr_data.dig('questionnaire', 'title')]], style.title_style)
          table([[org_name]], style.normal_text_style)
        end
      end

      def set_footer
        footer_text =
          "#{user_data['first_name']} #{user_data['last_name']} | Date of birth: #{date_of_birth}"

        bounding_box([0, bounds.bottom], width: 550, height: 20) do
          text footer_text, size: 9, align: :center
        end
      end

      def set_logo
        image VA_LOGO, style.logo_style
      end

      def set_body
        bounding_box([0, 585], width: 520, height: 550) do
          set_basic_appointment_info
          set_basic_demographics
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
          table.column(1).font_style = :bold
        end
      end

      def set_basic_demographics
        table([['Veteran information']], style.heading_one_style)
        table((set_about + set_address + set_phone), style.default_table_style) do |table|
          table.column(1).font_style = :bold
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
          ['Country:', user_data.dig('address', 'country')],
          ['Mailing address:', user_data['mailing_address']],
          ['Home address:', user_data['home_address']]
        ]
      end

      def set_phone
        [
          ['Home phone:', user_data['home_phone']],
          ['Mobile phone:', user_data['mobile_phone']],
          ['Work phone:', user_data['work_phone']]
        ]
      end

      def set_questionnaire_items
        questions = questionnaire_response.questionnaire_response_data['item']

        questions.each do |q|
          answers = q['answer']

          table([[q['text'], '']], style.table_question_style)

          answers.each do |a|
            blank_table
            table([['', a['valueString']]], style.table_answer_style)
          end

          blank_table_two
        end
      end

      def set_provider_info_text
        table([["Your questionnaire was sent to your provider on #{qr_submitted_time}"]], style.heading_two_style)
        table([['Your provider will discuss the information on your questionnaire during your appointment:']],
              style.normal_text_style)
      end

      def qr_submitted_time
        questionnaire_response.created_at.in_time_zone.to_date.strftime(QR_DATE_FORMAT)
      end

      def appointment_date
        DateTime.strptime(appointment.resource.start).strftime(DATE_FORMAT)
      end

      def appointment_time
        DateTime.strptime(appointment.resource.start).strftime(TIME_FORMAT)
      end

      def appointment_destination
        "#{loc_name}, #{org_name}"
      end

      def full_name
        "#{user_data['first_name']&.downcase&.capitalize} #{user_data['last_name']&.downcase&.capitalize}"
      end

      def date_of_birth
        DateTime.parse(user_data['date_of_birth']).strftime(HEADER_DATE_FORMAT)
      end

      def set_qr_header
        table([['Prepare for your visit']], style.heading_one_style)
        blank_table
      end

      def blank_table
        table([['']], style.blank_table)
      end

      def blank_table_two
        table([['']], style.blank_table_two)
      end

      def org_name
        org.resource.name
      end

      def loc_name
        location.resource.name
      end

      def header_columns
        [[today, VA_URL]]
      end

      def today
        DateTime.now.to_date.strftime(HEADER_DATE_FORMAT)
      end

      def user_data
        @user_data ||= questionnaire_response.user_demographics_data
      end

      def qr_data
        @qr_data ||= questionnaire_response.questionnaire_response_data
      end
    end
  end
end
