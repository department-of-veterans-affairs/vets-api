# frozen_string_literal: true

module RepresentationManagement
  class AccreditedIndividualSearch
    include ActiveModel::Model

    PERMITTED_MAX_DISTANCES = %w[5 10 25 50 100 200].freeze # in miles, no distance provided will default to "all"
    PERMITTED_SORTS = %w[distance_asc first_name_asc first_name_desc last_name_asc last_name_desc].freeze
    # claim_agents and veteran_service_officer are types leftover from the old Veteran::Service::Representative model
    # and are not used in AccreditedIndividual. They are included here for backwards compatibility.
    # They will be mapped to the individual_type used in AccreditedIndividual.
    # They can be removed once the frontend is updated to use the new types.
    PERMITTED_TYPES = %w[attorney claims_agent representative claim_agents veteran_service_officer].freeze

    attr_accessor :distance, :lat, :long, :name, :page, :per_page, :sort, :type

    validates :distance, inclusion: { in: PERMITTED_MAX_DISTANCES }, allow_nil: true
    validates :lat, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
    validates :long, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
    validates :page, numericality: { only_integer: true }, allow_nil: true
    validates :per_page, numericality: { only_integer: true }, allow_nil: true
    validates :sort, inclusion: { in: PERMITTED_SORTS }, allow_nil: true
    validates :type, presence: true, inclusion: { in: PERMITTED_TYPES }
  end
end
