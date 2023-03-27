# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'
require 'va_profile/concerns/defaultable'
require 'va_profile/concerns/expirable'

module VAProfile
  module Models
    class Telephone < Base
      include VAProfile::Concerns::Defaultable
      include VAProfile::Concerns::Expirable

      VALID_AREA_CODE_REGEX = /[0-9]+/
      VALID_PHONE_NUMBER_REGEX = /[^a-zA-Z]+/

      MOBILE      = 'MOBILE'
      HOME        = 'HOME'
      WORK        = 'WORK'
      FAX         = 'FAX'
      TEMPORARY   = 'TEMPORARY'
      PHONE_TYPES = [MOBILE, HOME, WORK, FAX, TEMPORARY].freeze

      attribute :area_code, String
      attribute :country_code, String
      attribute :created_at, Common::ISO8601Time
      attribute :extension, String
      attribute :effective_end_date, Common::ISO8601Time
      attribute :effective_start_date, Common::ISO8601Time
      attribute :id, Integer
      attribute :is_international, Boolean, default: false
      attribute :is_textable, Boolean
      attribute :is_text_permitted, Boolean
      attribute :is_tty, Boolean
      attribute :is_voicemailable, Boolean
      attribute :phone_number, String
      attribute :phone_type, String
      attribute :source_date, Common::ISO8601Time
      attribute :source_system_user, String
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time
      attribute :vet360_id, String

      validates(
        :area_code,
        presence: true,
        format: { with: VALID_AREA_CODE_REGEX },
        length: { maximum: 3, minimum: 3 }
      )

      validates(
        :phone_number,
        presence: true,
        format: { with: VALID_PHONE_NUMBER_REGEX },
        length: { maximum: 14, minimum: 1 }
      )

      validates(
        :extension,
        allow_blank: true,
        numericality: { only_integer: true },
        length: { maximum: 6 }
      )

      validates(
        :phone_type,
        presence: true,
        inclusion: { in: PHONE_TYPES }
      )

      validates(
        :is_international,
        inclusion: { in: [false] }
      )

      validates(
        :country_code,
        presence: true,
        inclusion: { in: ['1'] }
      )

      def formatted_phone
        return if phone_number.blank?

        # TODO: support international numbers

        return_val = "(#{area_code}) #{phone_number[0..2]}-#{phone_number[3..7]}"
        return_val += " Ext. #{extension}" if extension.present?

        return_val
      end

      # Converts an instance of the Telphone model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      #
      # rubocop:disable Metrics/MethodLength
      def in_json
        {
          bio: {
            areaCode: @area_code,
            countryCode: @country_code,
            internationalIndicator: @is_international,
            originatingSourceSystem: SOURCE_SYSTEM,
            phoneNumber: @phone_number,
            phoneNumberExt: @extension,
            phoneType: @phone_type,
            sourceDate: @source_date,
            sourceSystemUser: @source_system_user,
            telephoneId: @id,
            textMessageCapableInd: @is_textable,
            textMessagePermInd: @is_text_permitted,
            ttyInd: @is_tty,
            vet360Id: @vet360_id,
            voiceMailAcceptableInd: @is_voicemailable,
            effectiveStartDate: @effective_start_date,
            effectiveEndDate: @effective_end_date
          }
        }.to_json
      end
      # rubocop:enable Metrics/MethodLength

      # Converts a decoded JSON response from VAProfile to an instance of the Telephone model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::Telephone] the model built from the response body
      def self.build_from(body)
        VAProfile::Models::Telephone.new(
          area_code: body['area_code'],
          country_code: body['country_code'],
          created_at: body['create_date'],
          extension: body['phone_number_ext'],
          id: body['telephone_id'],
          is_international: body['international_indicator'],
          is_textable: body['text_message_capable_ind'],
          is_text_permitted: body['text_message_perm_ind'],
          is_voicemailable: body['voice_mail_acceptable_ind'],
          phone_number: body['phone_number'],
          phone_type: body['phone_type'],
          source_date: body['source_date'],
          transaction_id: body['tx_audit_id'],
          is_tty: body['tty_ind'],
          updated_at: body['update_date'],
          vet360_id: body['vet360_id'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date']
        )
      end
    end
  end
end
