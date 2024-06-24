# frozen_string_literal: true

module RepresentationManagement
  class Form2122Base
    include ActiveModel::Model

    veteran_attrs = %i[
      veteran_first_name veteran_middle_initial veteran_last_name
      veteran_social_security_number
      veteran_file_number
      veteran_address_line1
      veteran_address_line2
      veteran_city
      veteran_country
      veteran_state_code
      veteran_zip_code
      veteran_zip_code_suffix
      veteran_area_code
      veteran_phone_number
      veteran_email
      veteran_service_number
      veteran_insurance_numbers
    ]

    claimant_attrs = %i[
      claimant_first_name
      claimant_middle_initial
      claimant_last_name
      claimant_address_line1
      claimant_address_line2
      claimant_city
      claimant_country
      claimant_state_code
      claimant_zip_code
      claimant_zip_code_suffix
      claimant_area_code
      claimant_phone_number
      claimant_email
      claimant_relationship
    ]

    consent_attrs = %i[
      record_consent
      consent_address_change
      consent_limits
    ]

    validates :veteran_first_name, presence: true, length: { maximum: 12 }
    validates :veteran_middle_initial, length: { maximum: 1 }
    validates :veteran_last_name, presence: true, length: { maximum: 18 }
    validates :veteran_social_security_number, presence: true, lenghth: { is: 9 }, numericality: { only_integer: true }
    validates :veteran_file_number, presence: true, length: { is: 9 }, numericality: { only_integer: true }
    validates :veteran_address_line1, presence: true, length: { maximum: 30 }
    validates :veteran_address_line2, length: { maximum: 5 }
    validates :veteran_city, presence: true, length: { maximum: 18 }
    validates :veteran_country, presence: true, length: { is: 2 }
    validates :veteran_state_code, presence: true, length: { is: 2 }
    validates :veteran_zip_code, presence: true, length: { is: 5 }, numericality: { only_integer: true }
    validates :veteran_zip_code_suffix, length: { is: 4 }, numericality: { only_integer: true }
    validates :veteran_area_code, length: { is: 3 }, numericality: { only_integer: true }
    validates :veteran_phone_number, length: { is: 7 }, numericality: { only_integer: true }
    validates :veteran_service_number, length: { is: 9 }, numericality: { only_integer: true }
    validates :veteran_insurance_numbers

    with_options if: claimant_first_name.present? do
      validates :claimant_first_name, presence: true, length: { maximum: 12 }
      validates :claimant_middle_initial, length: { maximum: 1 }
      validates :claimant_last_name, presence: true, length: { maximum: 18 }
      validates :claimant_address_line1, presence: true, length: { maximum: 30 }
      validates :claimant_address_line2, length: { maximum: 5 }
      validates :claimant_city, presence: true, length: { maximum: 18 }
      validates :claimant_country, presence: true, length: { is: 2 }
      validates :claimant_state_code, presence: true, length: { is: 2 }
      validates :claimant_zip_code, presence: true, length: { is: 5 }, numericality: { only_integer: true }
      validates :claimant_zip_code_suffix, length: { is: 4 }, numericality: { only_integer: true }
      validates :claimant_area_code, length: { is: 3 }, numericality: { only_integer: true }
      validates :claimant_phone_number, length: { is: 7 }, numericality: { only_integer: true }
    end

    attr_accessor [veteran_attrs, claimant_attrs, consent_attrs].flatten
  end
end
