# frozen_string_literal: true

module EMIS
  module Models
    # EMIS Combat Pay data for a veteran
    class CombatPay
      include Virtus.model

      attribute :segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :type_code, String
      attribute :combat_zone_country_code, String
    end
  end
end
