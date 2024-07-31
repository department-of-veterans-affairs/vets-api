# frozen_string_literal: true

module RepresentationManagement
  class Form2122Base
    include ActiveModel::Model

    FOUR_DIGIT_NUMBER = /\A\d{4}\z/
    FIVE_DIGIT_NUMBER = /\A\d{5}\z/
    NINE_DIGIT_NUMBER = /\A\d{9}\z/
    TEN_DIGIT_NUMBER = /\A\d{10}\z/
    LIMITATIONS_OF_CONSENT = %w[ALCOHOLISM DRUG_ABUSE HIV SICKLE_CELL].freeze

    veteran_attrs = %i[
      veteran_first_name veteran_middle_initial veteran_last_name
      veteran_social_security_number
      veteran_va_file_number
      veteran_date_of_birth
      veteran_address_line1
      veteran_address_line2
      veteran_city
      veteran_country
      veteran_state_code
      veteran_zip_code
      veteran_zip_code_suffix
      veteran_phone
      veteran_email
      veteran_service_number
      veteran_insurance_numbers
    ]

    claimant_attrs = %i[
      claimant_first_name
      claimant_middle_initial
      claimant_last_name
      claimant_date_of_birth
      claimant_relationship
      claimant_address_line1
      claimant_address_line2
      claimant_city
      claimant_country
      claimant_state_code
      claimant_zip_code
      claimant_zip_code_suffix
      claimant_phone
      claimant_email
    ]

    consent_attrs = %i[
      record_consent
      consent_address_change
      consent_limits
    ]

    attr_accessor(*[veteran_attrs, claimant_attrs, consent_attrs].flatten)

    validates :veteran_first_name, presence: true, length: { maximum: 12 }
    validates :veteran_middle_initial, length: { maximum: 1 }
    validates :veteran_last_name, presence: true, length: { maximum: 18 }
    validates :veteran_social_security_number, presence: true, format: { with: NINE_DIGIT_NUMBER }
    validates :veteran_va_file_number,
              format: { with: NINE_DIGIT_NUMBER },
              if: -> { veteran_va_file_number.present? }
    validates :veteran_date_of_birth, presence: true
    validates :veteran_address_line1, presence: true, length: { maximum: 30 }
    validates :veteran_address_line2,
              length: { maximum: 5 },
              if: -> { veteran_address_line2.present? }
    validates :veteran_city, presence: true, length: { maximum: 18 }
    validates :veteran_country, presence: true, length: { is: 2 }
    validates :veteran_state_code, presence: true, length: { is: 2 }
    validates :veteran_zip_code, presence: true, length: { is: 5 }, format: { with: FIVE_DIGIT_NUMBER }
    validates :veteran_zip_code_suffix,
              length: { is: 4 },
              format: { with: FOUR_DIGIT_NUMBER },
              if: -> { veteran_zip_code_suffix.present? }
    validates :veteran_phone,
              length: { is: 10 },
              format: { with: TEN_DIGIT_NUMBER },
              if: -> { veteran_phone.present? }
    validates :veteran_service_number,
              length: { is: 9 },
              format: { with: NINE_DIGIT_NUMBER },
              if: -> { veteran_service_number.present? }

    validate :consent_limits_must_contain_valid_values

    with_options if: -> { claimant_first_name.present? } do
      validates :claimant_first_name, presence: true, length: { maximum: 12 }
      validates :claimant_middle_initial, length: { maximum: 1 }
      validates :claimant_last_name, presence: true, length: { maximum: 18 }
      validates :claimant_date_of_birth, presence: true
      validates :claimant_relationship, presence: true
      validates :claimant_address_line1, presence: true, length: { maximum: 30 }
      validates :claimant_address_line2, length: { maximum: 5 }
      validates :claimant_city, presence: true, length: { maximum: 18 }
      validates :claimant_country, presence: true, length: { is: 2 }
      validates :claimant_state_code, presence: true, length: { is: 2 }
      validates :claimant_zip_code, presence: true, length: { is: 5 }, format: { with: FIVE_DIGIT_NUMBER }
      validates :claimant_zip_code_suffix, length: { is: 4 }, format: { with: FOUR_DIGIT_NUMBER }
      validates :claimant_phone, length: { is: 10 }, format: { with: TEN_DIGIT_NUMBER }
    end

    private

    def consent_limits_must_contain_valid_values
      return if consent_limits.nil?
      return unless consent_limits.any?
      return if consent_limits.size == 1 && consent_limits.first.blank?

      consent_limits.each do |limit|
        unless LIMITATIONS_OF_CONSENT.include?(limit)
          errors.add(:consent_limits,
                     "#{limit} is not a valid limitation of consent")
        end
      end
    end
  end
end
