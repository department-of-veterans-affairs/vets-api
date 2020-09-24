# frozen_string_literal: true

module EMIS
  module Models
    # EMIS Military Occupation data
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each occupation
    #     record.
    # @!attribute dod_occupation_type
    #   @return [String] code that represents the Department of Defense's standard Occupation
    #     Code. Length changed from 4 to 6 bytes in September 2013.
    #     See https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/SiP-Prefill/Prefill/eMIS_Integration/eMIS_Documents/VA-SAT%204.6%20DD_051216.xlsm
    #     for details. System name: DOD_OCC_CD
    # @!attribute service_specific_occupation_type
    #   @return [String] code, set by each Service, that represents a member's occupation in
    #     that Service. Please refer to Occupational Conversion Index - DoD 1312.1-I. The
    #     Service Occupation Codes for the individual services are listed in the Index.
    # @!attribute service_occupation_date
    #   @return [Date] date when the member's service occupation was last updated.
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
