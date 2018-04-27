# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class State < Common::Base
    attribute :code, String
    attribute :name, String
    attribute :first_five_zip, String
    attribute :last_five_zip, String
    attribute :lower_indicator, String

    def id
      code
    end

    # Default sort should be by name ascending
    def <=>(other)
      code <=> other.code
    end
  end
end
