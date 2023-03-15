# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'

class LighthouseRatedDisabilitiesProvider
  include RatedDisabilitiesProvider
  def initialize(_current_user)
    raise NotImplementedError
  end

  def get_rated_disabilities
    raise NotImplementedError
  end
end
