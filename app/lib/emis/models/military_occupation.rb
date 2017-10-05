# frozen_string_literal: true

module EMIS
  module Models
    class MilitaryOccupation
      include Virtus.model

      attribute :segment_identifier, String
      attribute :dod_occupation_type, String
      attribute :occupation_type, String
      attribute :service_specific_occupation_type, String
      attribute :service_occupation_date, Date
    end
  end
end
