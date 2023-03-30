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
      class Demographics
        HEADER_DATE_FORMAT = '%m/%d/%Y'

        attr_reader :opts, :composer

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::Demographics}
        #
        # @param args [Hash]
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Demographics]
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
        # generating the footer for the Patient's QR
        #
        # @return [String]
        #
        def draw
          demographics_header
          full_name
          dob
          gender
          country
          mailing_address
          home_address
          home_phone
          mobile_phone
          work_phone
        end

        ##
        # Set the demographics section header
        #
        # @return [String]
        #
        def demographics_header
          composer.text_box 'Veteran information', at: [30, composer.bounds.top - 175], size: 16, style: :bold
        end

        ##
        # Set the demographics section patient full name
        #
        # @return [String]
        #
        def full_name
          set_text('Name:', 205)
          set_text(formatted_name, 205, 'value')
        end

        ##
        # Set the demographics section patient date of birth
        #
        # @return [String]
        #
        def dob
          set_text('Date of birth:', 225)
          set_text(formatted_dob, 225, 'value')
        end

        ##
        # Set the demographics section patient gender
        #
        # @return [String]
        #
        def gender
          value = user_data['gender'] || ''

          set_text('Gender:', 245)
          set_text(value, 245, 'value')
        end

        ##
        # Set the demographics section patient country name
        #
        # @return [String]
        #
        def country
          value = user_data&.dig('address', 'country') || ''

          set_text('Country:', 265)
          set_text(value, 265, 'value')
        end

        ##
        # Set the demographics section patient mailing address
        #
        # @return [String]
        #
        def mailing_address
          value = format_address(user_data['mailing_address'])

          set_text('Mailing address:', 285)
          set_text(value, 285, 'value')
        end

        ##
        # Set the demographics section patient home address
        #
        # @return [String]
        #
        def home_address
          value = format_address(user_data['home_address'])

          set_text('Home address:', 305)
          set_text(value, 305, 'value')
        end

        ##
        # Set the demographics section patient home phone
        #
        # @return [String]
        #
        def home_phone
          value = format_phone(user_data['home_phone'])

          set_text('Home phone:', 325)
          set_text(value, 325, 'value')
        end

        ##
        # Set the demographics section patient mobile phone
        #
        # @return [String]
        #
        def mobile_phone
          value = format_phone(user_data['mobile_phone'])

          set_text('Mobile phone:', 345)
          set_text(value, 345, 'value')
        end

        ##
        # Set the demographics section patient work phone
        #
        # @return [String]
        #
        def work_phone
          value = format_phone(user_data['work_phone'])

          set_text('Work phone:', 365)
          set_text(value, 365, 'value')
        end

        ##
        # Dynamically builds demographics text based on a few key inputs
        #
        # @param value [String]
        # @param y_dec [Integer]
        # @param type [String]
        # @return [String]
        #
        def set_text(value, y_dec, type = 'key')
          x = type == 'key' ? 30 : 120
          style = type == 'key' ? :normal : :medium

          composer.text_box(value, at: [x, composer.bounds.top - y_dec], size: 12, style:)
        end

        ##
        # The patient's formatted full name
        #
        # @return [String]
        #
        def formatted_name
          "#{user_data['first_name']&.downcase&.capitalize} #{user_data['last_name']&.downcase&.capitalize}"
        end

        ##
        # The patient's formatted data of birth
        #
        # @return [String]
        #
        def formatted_dob
          DateTime.parse(user_data['date_of_birth'])&.strftime(HEADER_DATE_FORMAT)
        end

        ##
        # The patient's formatted address; home, mailing etc
        #
        # @param addr [Hash]
        # @return [String]
        #
        def format_address(addr)
          return '' if addr.blank?

          street_info = [addr['address_line1'], addr['address_line2'], addr['address_line3']].compact.join(' ')

          "#{street_info}, #{addr['city']}, #{addr['state_code']} #{addr['zip_code']}"
        end

        ##
        # The patient's formatted phone; work, home, mobile etc
        #
        # @param phone_hash [Hash]
        # @return [String]
        #
        def format_phone(phone_hash)
          return '' if phone_hash.blank?

          area_code = phone_hash['area_code']
          prefix = phone_hash['phone_number']&.first(3)
          line = phone_hash['phone_number']&.last(4)

          [area_code, prefix, line].compact.join('-')
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
