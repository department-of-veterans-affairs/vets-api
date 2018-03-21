# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class Cemetery < Common::Base
    attribute :cemetery_type, String
    attribute :name, String
    attribute :num, String

    def id
      num
    end

    # Default sort should be by name ascending
    def <=>(other)
      name <=> other.name
    end
  end
end
