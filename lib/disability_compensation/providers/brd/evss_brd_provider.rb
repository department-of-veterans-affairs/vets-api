# frozen_string_literal: true

require 'disability_compensation/providers/brd/brd_provider'
require 'evss/reference_data/service'

class EvssBRDProvider
  include BRDProvider

  def initialize(current_user)
    @service = EVSS::ReferenceData::Service.new(current_user)
  end

  def get_separation_locations
    @service.get_separation_locations
  end
end
