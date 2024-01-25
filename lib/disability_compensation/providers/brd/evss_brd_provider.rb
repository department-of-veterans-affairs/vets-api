# frozen_string_literal: true

require 'disability_compensation/providers/brd/brd_provider'
require 'disability_compensation/responses/intake_sites_response'
require 'evss/reference_data/intake_sites_response'

class EvssBRDProvider
  include BRDProvider

  def initialize(current_user)
    @service = EVSS::ReferenceData::Service.new(current_user)
  end

  def get_separation_locations
    @service.get_separation_locations
  end
end