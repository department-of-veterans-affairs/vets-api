# frozen_string_literal: true

module RepresentationManagement
  class Form2122aData < RepresentationManagement::Form2122Base
    REPRESENTATIVE_TYPES = %w[ATTORNEY AGENT INDIVIDUAL VSO_REPRESENTATIVE].freeze
    VETERAN_SERVICE_BRANCHES = %w[ARMY NAVY AIR_FORCE MARINE_CORPS COAST_GUARD SPACE_FORCE NOAA
                                  USPHS].freeze

    veteran_attrs = %i[
      veteran_service_branch
    ]

    attr_accessor(*[veteran_attrs].flatten)

    validates :representative_id, presence: true

    validates :veteran_service_branch,
              inclusion: { in: VETERAN_SERVICE_BRANCHES },
              if: -> { veteran_service_branch.present? }
  end
end
