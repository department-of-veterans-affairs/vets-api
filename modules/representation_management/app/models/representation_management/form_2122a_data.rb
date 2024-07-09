# frozen_string_literal: true

module RepresentationManagement
  class Form2122aData < RepresentationManagement::Form2122Base
    representative_attrs = %i[
      representative_type
      representative_first_name
      representative_middle_initial
      representative_last_name
      representative_address_line1
      representative_address_line2
      representative_city
      representative_country
      representative_state_code
      representative_zip_code
      representative_zip_code_suffix
      representative_phone
      representative_email_address
    ]

    representative_consent_attrs = %i[
      conditions_of_appointment
    ]

    veteran_attrs = %i[
      veteran_service_branch
      veteran_service_branch_other
    ]

    attr_accessor(*[representative_attrs, representative_consent_attrs, veteran_attrs].flatten)

    validates :representative_type, presence: true
    validates :representative_first_name, presence: true, length: { maximum: 12 }
    validates :representative_middle_initial, length: { maximum: 1 }
    validates :representative_last_name, presence: true, length: { maximum: 18 }
    validates :representative_address_line1, presence: true, length: { maximum: 30 }
    validates :representative_address_line2, length: { maximum: 5 }
    validates :representative_city, presence: true, length: { maximum: 18 }
    validates :representative_country, presence: true, length: { is: 2 }
    validates :representative_state_code, presence: true, length: { is: 2 }
    validates :representative_zip_code, presence: true, length: { is: 5 }, format: { with: FIVE_DIGIT_NUMBER }
    validates :representative_zip_code_suffix, length: { is: 4 }, format: { with: FOUR_DIGIT_NUMBER }
    validates :representative_phone, presence: true, length: { is: 10 }, format: { with: TEN_DIGIT_NUMBER }
  end
end
