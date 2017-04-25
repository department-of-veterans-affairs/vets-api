# frozen_string_literal: true

module EMIS
  module Models
    class UnitInformation
      include Virtus.model

      attribute :segment_identifier, String
      attribute :identification_code, String
      attribute :uic_type_code, String
      attribute :assigned_date, Date
    end
  end
end
