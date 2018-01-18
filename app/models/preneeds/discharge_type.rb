# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class DischargeType < Common::Base
    attribute :id, Integer
    attribute :description, String

    # Default sort should be by description ascending
    def <=>(other)
      description <=> other.description
    end
  end
end
