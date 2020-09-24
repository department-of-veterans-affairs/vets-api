# frozen_string_literal: true

module EMIS
  module Models
    # EMIS unit information data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each unit
    #     identification code record.
    # @!attribute identification_code
    #   @return [String] Unit Identification Code. The data is received monthly from data
    #     feeds for position reporting and updating DEERS.
    # @!attribute uic_type_code
    #   @return [String] code that represents a specific kind of unit identification
    #     code.
    #       S => Assigned
    #       T => Attached
    # @!attribute assigned_date
    #   @return [Date] date when the batch file that contained the unit identification code
    #     update was created.
    class UnitInformation
      include Virtus.model

      attribute :segment_identifier, String
      attribute :identification_code, String
      attribute :uic_type_code, String
      attribute :assigned_date, Date
    end
  end
end
