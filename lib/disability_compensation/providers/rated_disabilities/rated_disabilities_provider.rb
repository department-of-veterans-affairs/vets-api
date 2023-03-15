# frozen_string_literal: true

module RatedDisabilitiesProvider
  def self.get_rated_disabilities
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end
end
