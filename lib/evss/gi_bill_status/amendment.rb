# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module GiBillStatus
    class Amendment < Common::Base
      attribute :on_campus_hours, Float
      attribute :online_hours, Float
      attribute :yellow_ribbon_amount, Float
      attribute :type, String
      attribute :status, String
      attribute :change_effective_date, String
    end
  end
end
