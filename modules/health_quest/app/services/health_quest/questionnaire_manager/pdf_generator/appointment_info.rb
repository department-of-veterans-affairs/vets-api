# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      #
      # Object for defining the basic appointment body
      #
      # @!attribute opts
      #   @return [Hash]
      # @!attribute composer
      #   @return [HealthQuest::QuestionnaireManager::PdfGenerator::Composer]
      class AppointmentInfo
        DATE_FORMAT = '%A, %B %d, %Y'
        DEFAULT_TIME_ZONE = 'Pacific Time (US & Canada)'
        FOOTER_DATE_FORMAT = '%m/%d/%Y'
        QR_DATE_FORMAT = '%B %d, %Y.'
        TIME_FORMAT = '%-I:%M %p'
        TIME_ZONE_FORMAT = '%Z'

        attr_reader :opts, :composer

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::AppointmentInfo}
        #
        # @param args [Hash]
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::AppointmentInfo]
        #
        def self.build(args = {})
          new(args)
        end

        def initialize(args)
          @opts = args[:opts]
          @composer = args[:composer]
        end

        ##
        # A pipeline method for determining the layout and
        # generating the appointment info for the Patient's QR
        #
        # @return [String]
        #
        def draw
          provider_text
          appointment_date
          appointment_time
          appointment_destination
        end

        ##
        # Set the appointment section provider
        #
        # @return [String]
        #
        def provider_text
          composer.text_box "Your questionnaire was sent to your provider on #{qr_submitted_time}",
                            at: [30, composer.bounds.top - 10], size: 16, style: :bold
          composer.text_box 'Your provider will discuss the information on your questionnaire during your appointment:',
                            at: [30, composer.bounds.top - 41], size: 12, style: :bold
        end

        ##
        # Set the appointment section date
        #
        # @return [String]
        #
        def appointment_date
          set_text('Date:', 90)
          set_text(formatted_date, 90, 'value')
        end

        ##
        # Set the appointment section time
        #
        # @return [String]
        #
        def appointment_time
          set_text('Time:', 115)
          set_text(formatted_time, 115, 'value')
        end

        ##
        # Set the appointment section destination
        #
        # @return [String]
        #
        def appointment_destination
          set_text('Location:', 135)
          set_text(formatted_destination, 135, 'value')
        end

        ##
        # Dynamically builds appointment info text based on a few key inputs
        #
        # @param value [String]
        # @param y_dec [Integer]
        # @param type [String]
        # @return [String]
        #
        def set_text(value, y_dec, type = 'key')
          x = type == 'key' ? 30 : 85
          style = type == 'key' ? :normal : :medium

          composer.text_box(value, at: [x, composer.bounds.top - y_dec], size: 12, style:)
        end

        ##
        # Return the QR submitted time, formatted
        #
        # @return [String]
        #
        def qr_submitted_time
          opts[:questionnaire_response]
            &.created_at
            &.in_time_zone(DEFAULT_TIME_ZONE)
            &.to_date
            &.strftime(QR_DATE_FORMAT)
        end

        ##
        # Return the formatted date
        #
        # @return [String]
        #
        def formatted_date
          utc = opts[:appointment]&.resource&.start

          DateTime.strptime(utc)&.in_time_zone(DEFAULT_TIME_ZONE)&.strftime(DATE_FORMAT)
        end

        ##
        # Return the formatted time
        #
        # @return [String]
        #
        def formatted_time
          utc = opts[:appointment]&.resource&.start
          time = DateTime.strptime(utc).in_time_zone(DEFAULT_TIME_ZONE)

          "#{time.strftime(TIME_FORMAT)} #{time.strftime(TIME_ZONE_FORMAT)}"
        end

        ##
        # Return the formatted appointment location
        #
        # @return [String]
        #
        def formatted_destination
          "#{opts[:location]&.resource&.name}, #{opts[:org]&.resource&.name}"
        end

        ##
        # The snapshot of the patient's demographics data
        # when the QR was submitted to the Lighthouse database
        #
        # @return [Hash]
        #
        def user_data
          @user_data ||= opts[:questionnaire_response]&.user_demographics_data
        end
      end
    end
  end
end
