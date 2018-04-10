# frozen_string_literal: true

module Vet360
  module Models
    class Telephone < Base
      PHONE_TYPES = %w[MOBILE HOME WORK FAX TEMPORARY].freeze

      attribute :area_code, String
      attribute :country_code, String
      attribute :created_at, Common::ISO8601Time
      attribute :effective_end_date, Common::ISO8601Time
      attribute :effective_start_date, Common::ISO8601Time
      attribute :extension, String
      attribute :id, Integer
      attribute :is_international, Boolean
      attribute :phone_number, String
      attribute :phone_type, String
      attribute :source_date, Common::ISO8601Time
      attribute :is_textable, Boolean
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
    end
  end
end
