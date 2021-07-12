# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      #
      # Object for defining the PDF footer layout
      #
      class BasicAppointmentInfo
        DATE_FORMAT = '%A, %B %d, %Y'
        DEFAULT_TIME_ZONE = 'Pacific Time (US & Canada)'
        FOOTER_DATE_FORMAT = '%m/%d/%Y'
        QR_DATE_FORMAT = '%B %d, %Y.'
        TIME_FORMAT = '%-I:%M %p'
        TIME_ZONE_FORMAT = '%Z'

        attr_reader :opts, :composer

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::Footer}
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Footer]
        #
        def self.build(args = {})
          new(args)
        end

        def initialize(args)
          @opts = args[:opts]
          @composer = args[:composer]
        end

        def draw
          composer.text_box "Your questionnaire was sent to your provider on #{qr_submitted_time}",
                            at: [30, composer.bounds.top - 10], size: 16, style: :bold
          composer.text_box 'Your provider will discuss the information on your questionnaire during your appointment:',
                            at: [30, composer.bounds.top - 41], size: 12, style: :bold

          composer.text_box 'Date:', at: [30, composer.bounds.top - 90], size: 12
          composer.text_box appointment_date, at: [90, composer.bounds.top - 90], size: 12, style: :medium
          composer.text_box 'Time:', at: [30, composer.bounds.top - 115], size: 12
          composer.text_box appointment_time, at: [90, composer.bounds.top - 115], size: 12, style: :medium
          composer.text_box 'Location:', at: [30, composer.bounds.top - 135], size: 12
          composer.text_box appointment_destination, at: [90, composer.bounds.top - 135], size: 12, style: :medium
        end

        def qr_submitted_time
          opts[:questionnaire_response]
            &.created_at
            &.in_time_zone(DEFAULT_TIME_ZONE)
            &.to_date
            &.strftime(QR_DATE_FORMAT)
        end

        def appointment_date
          appt_utc_time = opts[:appointment]&.resource&.start
          time = DateTime.strptime(appt_utc_time)&.in_time_zone(DEFAULT_TIME_ZONE)

          time.strftime(DATE_FORMAT)
        end

        def appointment_time
          appt_utc_time = opts[:appointment]&.resource&.start
          time = DateTime.strptime(appt_utc_time).in_time_zone(DEFAULT_TIME_ZONE)
          local_time = time.strftime(TIME_FORMAT)
          local_time_zone = time.strftime(TIME_ZONE_FORMAT)

          "#{local_time} #{local_time_zone}"
        end

        def appointment_destination
          "#{opts[:location]&.resource&.name}, #{opts[:org]&.resource&.name}"
        end

        def user_data
          @user_data ||= opts[:questionnaire_response]&.user_demographics_data
        end
      end
    end
  end
end
