# frozen_string_literal: true

module RepresentationManagement
  class Form2122aData < RepresentationManagement::Form2122Base
    REPRESENTATIVE_TYPES = %w[ATTORNEY AGENT INDIVIDUAL VSO_REPRESENTATIVE].freeze
    VETERAN_SERVICE_BRANCHES = %w[ARMY NAVY AIR_FORCE MARINE_CORPS COAST_GUARD SPACE_FORCE NOAA
                                  USPHS].freeze

    representative_consent_attrs = %i[
      conditions_of_appointment
    ]

    veteran_attrs = %i[
      veteran_service_branch
    ]

    attr_accessor(*[representative_consent_attrs, veteran_attrs].flatten)

    validates :veteran_service_branch,
              inclusion: { in: VETERAN_SERVICE_BRANCHES },
              if: -> { veteran_service_branch.present? }
    validates :representative_type, presence: true, inclusion: { in: REPRESENTATIVE_TYPES }
    validates :representative_first_name, presence: true, length: { maximum: 12 }
    validates :representative_middle_initial, length: { maximum: 1 }
    validates :representative_last_name, presence: true, length: { maximum: 18 }
    validates :representative_address_line1, presence: true, length: { maximum: 30 }
    validates :representative_address_line2, length: { maximum: 5 }
    validates :representative_city, presence: true, length: { maximum: 18 }
    validates :representative_country, presence: true, length: { is: 2 }
    validates :representative_state_code, presence: true, length: { is: 2 }
    validates :representative_zip_code, presence: true, length: { is: 5 }, format: { with: FIVE_DIGIT_NUMBER }
    validates :representative_zip_code_suffix, length: { is: 4 }, format: { with: FOUR_DIGIT_NUMBER },
                                               if: -> { representative_zip_code_suffix.present? }
    validates :representative_phone, presence: true, length: { is: 10 }, format: { with: TEN_DIGIT_NUMBER }
  end
end
