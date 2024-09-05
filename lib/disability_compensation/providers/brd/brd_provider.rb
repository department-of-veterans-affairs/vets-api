# frozen_string_literal: true

module BRDProvider
  def self.get_separation_locations
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end
end
