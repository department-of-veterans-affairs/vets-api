# frozen_string_literal: true

module Vet360
  module Models
    class Telephone < Base
      PHONE_TYPES = %w[MOBILE HOME WORK FAX TEMPORARY].freeze

      attribute :area_code, String
      attribute :country_code, String
      attribute :created_at, Common::ISO8601Time
      attribute :extension, String
      attribute :id, Integer
      attribute :is_international, Boolean
      attribute :is_textable, Boolean
      attribute :phone_number, String
      attribute :phone_type, String
      attribute :source_date, Common::ISO8601Time
      attribute :transaction_id, String
      attribute :is_tty, Boolean
      attribute :updated_at, Common::ISO8601Time
      attribute :is_voicemailable, Boolean

      validates(
        :area_code,
        presence: true,
        format: { with: /[0-9]+/ },
        length: { maximum: 3, minimum: 3 }
      )

      validates(
        :phone_number,
        presence: true,
        format: { with: /[^a-zA-Z]+/ },
        length: { maximum: 14, minimum: 1 }
      )

      validates(
        :extension,
        length: { maximum: 10 }
      )

      validates(
        :phone_type,
        presence: true,
        inclusion: { in: PHONE_TYPES }
      )

      def self.from_response(body)
        Vet360::Models::Telephone.new(
          area_code: body['area_code'],
          country_code: body['country_code'],
          created_at: body['create_date'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date'],
          extension: body['phone_number_ext'],
          id: body['telephone_id'],
          is_international: body['international_indicator'],
          phone_number: body['phone_number'],
          phone_type: body['phone_type'],
          source_date: body['source_date'],
          is_textable: body['text_message_capable_ind'],
          transaction_id: body['tx_audit_id'],
          is_tty: body['tty_ind'],
          updated_at: body['update_date'],
          is_voicemailable: body['voice_mail_acceptable_ind']
        )
      end
    end
  end
end
