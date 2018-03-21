# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module GiBillStatus
    class Entitlement < Common::Base
      attribute :months, Integer
      attribute :days, Integer
    end
  end
end
