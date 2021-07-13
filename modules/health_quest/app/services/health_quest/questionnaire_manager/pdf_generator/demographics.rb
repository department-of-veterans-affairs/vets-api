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
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Demographics]
        #
        def self.build(args = {})
          new(args)
        end

        def initialize(args)
          @opts = args[:opts]
          @composer = args[:composer]
        end

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

        def demographics_header
          composer.text_box 'Veteran information', at: [30, composer.bounds.top - 175], size: 16, style: :bold
        end

        def full_name
          composer.text_box 'Name:', at: [30, composer.bounds.top - 205], size: 12
          composer.text_box formatted_name, at: [120, composer.bounds.top - 205], size: 12, style: :medium
        end

        def dob
          composer.text_box 'Date of birth:', at: [30, composer.bounds.top - 225], size: 12
          composer.text_box formatted_dob, at: [120, composer.bounds.top - 225], size: 12, style: :medium
        end

        def gender
          value = user_data['gender'] || ''

          composer.text_box 'Gender:', at: [30, composer.bounds.top - 245], size: 12
          composer.text_box value, at: [120, composer.bounds.top - 245], size: 12, style: :medium
        end

        def country
          value = user_data&.dig('address', 'country') || ''

          composer.text_box 'Country:', at: [30, composer.bounds.top - 265], size: 12
          composer.text_box value, at: [120, composer.bounds.top - 265], size: 12, style: :medium
        end

        def mailing_address
          value = format_address(user_data['mailing_address'])

          composer.text_box 'Mailing address:', at: [30, composer.bounds.top - 285], size: 12
          composer.text_box value, at: [120, composer.bounds.top - 285], size: 12, style: :medium
        end

        def home_address
          value = format_address(user_data['home_address'])

          composer.text_box 'Home address:', at: [30, composer.bounds.top - 305], size: 12
          composer.text_box value, at: [120, composer.bounds.top - 305], size: 12, style: :medium
        end

        def home_phone
          value = format_phone(user_data['home_phone'])

          composer.text_box 'Home phone:', at: [30, composer.bounds.top - 325], size: 12
          composer.text_box value, at: [120, composer.bounds.top - 325], size: 12, style: :medium
        end

        def mobile_phone
          value = format_phone(user_data['mobile_phone'])

          composer.text_box 'Home phone:', at: [30, composer.bounds.top - 345], size: 12
          composer.text_box value, at: [120, composer.bounds.top - 345], size: 12, style: :medium
        end

        def work_phone
          value = format_phone(user_data['work_phone'])

          composer.text_box 'Home phone:', at: [30, composer.bounds.top - 365], size: 12
          composer.text_box value, at: [120, composer.bounds.top - 365], size: 12, style: :medium
        end

        def formatted_name
          "#{user_data['first_name']&.downcase&.capitalize} #{user_data['last_name']&.downcase&.capitalize}"
        end

        def formatted_dob
          DateTime.parse(user_data['date_of_birth'])&.strftime(HEADER_DATE_FORMAT)
        end

        def format_address(addr)
          return '' if addr.blank?

          street_info = [addr['address_line1'], addr['address_line2'], addr['address_line3']].compact.join(' ')
          city = addr['city']
          state = addr['state_code']
          zip = addr['zip_code']

          "#{street_info}, #{city}, #{state} #{zip}"
        end

        def format_phone(phone_hash)
          return '' if phone_hash.blank?

          area_code = phone_hash['area_code']
          prefix = phone_hash['phone_number']&.first(3)
          line = phone_hash['phone_number']&.last(4)

          [area_code, prefix, line].compact.join('-')
        end

        def user_data
          @user_data ||= opts[:questionnaire_response]&.user_demographics_data
        end
      end
    end
  end
end
