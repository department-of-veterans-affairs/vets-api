# frozen_string_literal: true

module RepresentationManagement
  class Form2122aData < RepresentationManagement::Form2122Base
    REPRESENTATIVE_TYPES = %w[ATTORNEY AGENT INDIVIDUAL VSO_REPRESENTATIVE].freeze
    VETERAN_SERVICE_BRANCHES = %w[ARMY NAVY AIR_FORCE MARINE_CORPS COAST_GUARD SPACE_FORCE NOAA
                                  USPHS].freeze
    TRUNCATION_LIMITS = {
      first_name: 12,
      middle_initial: 1,
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

    def representative_field_truncated(field)
      result = representative.public_send(field)
      limit = TRUNCATION_LIMITS[field]

      raise StandardError "#{field} does not have a truncation limit defined" unless limit

      if result.present?
        result[0..limit - 1]
      else
        ''
      end
    end

    def representative_zip_code_expanded
      if representative.zip_suffix.blank?
        [representative.zip_code[0..4], representative.zip_code[5..8]]
      else
        [representative.zip_code[0..4], representative.zip_suffix[0..3]]
      end
    end
  end
end
