# frozen_string_literal: true

module RepresentationManagement
  class Form2122aData < RepresentationManagement::Form2122Base
    REPRESENTATIVE_TYPES = %w[ATTORNEY AGENT INDIVIDUAL VSO_REPRESENTATIVE].freeze
    VETERAN_SERVICE_BRANCHES = %w[ARMY NAVY AIR_FORCE MARINE_CORPS COAST_GUARD SPACE_FORCE NOAA
                                  USPHS].freeze
    TRUNCATION_LIMITS = {
      first_name: 12,
      last_name: 18,
      address_line1: 30,
      address_line2: 5,
      city: 18,
      state_code: 2,
      zip_code: 5,
      email: 78
    }.freeze

    consent_attrs = %i[
      consent_inside_access
      consent_outside_access
      consent_team_members
    ]

    veteran_attrs = %i[
      veteran_service_branch
    ]

    attr_accessor(*[veteran_attrs, consent_attrs].flatten)

    validates :representative_id, presence: true

    validates :veteran_service_branch,
              inclusion: { in: VETERAN_SERVICE_BRANCHES },
              if: -> { veteran_service_branch.present? }

    def representative_first_name_truncated
      representative.first_name[0..11]
    end

    def representative_last_name_truncated
      representative.last_name[0..17]
    end

    def representative_address_line1_truncated
      representative.address_line1[0..29]
    end

    def representative_address_line2_truncated
      representative.address_line2[0..4]
    end

    def representative_field_truncated(field)
      representative.public_send(field)[0..TRUNCATION_LIMITS[field] - 1]
    end
  end
end
