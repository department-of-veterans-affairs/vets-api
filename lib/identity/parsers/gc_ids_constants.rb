# frozen_string_literal: true

module Identity
  module Parsers
    module GCIdsConstants
      # Originating IDs, defines what underlying system the ID has been sourced from
      VA_ROOT_OID = '2.16.840.1.113883.4.349'
      DOD_ROOT_OID = '2.16.840.1.113883.3.42.10001.100001.12'

      # The follow set of regex match each full ID format and extract the specific ID value from each
      # They tend to follow the format: <icn>^<id_type>^<assigning_authority>^<assigning_facility>^<id_state>

      # ICN_REGEX, ex. 16701377^NI^200M^USVHA^A
      ICN_REGEX = /^\w+\^NI\^200M\^USVHA\^\w+$/.freeze
      # PERMANENT_ICN_REGEX, ex. 1008830476V316605^NI^200M^USVHA^P
      PERMANENT_ICN_REGEX = /^\w+\^NI\^200M\^USVHA\^P$/.freeze
      # SEC_ID_REGEX, ex. 1008830476^PN^200PROV^USDVA^A
      SEC_ID_REGEX = /^\w+\^PN\^200PROV\^USDVA\^A$/.freeze
      # MHV_IDS_REGEX, ex. 123456^PI^200MHV^USVHA^P
      MHV_IDS_REGEX = /^\w+\^PI\^200MH.{0,1}\^\w+\^\w+$/.freeze
      # ACTIVE_MHV_IDS_REGEX, ex. 123456^PI^200MHV^USVHA^A
      ACTIVE_MHV_IDS_REGEX = /^\w+\^PI\^200MH.{0,1}\^\w+\^A$/.freeze
      # EDIPI_REGEX, ex. 2107307560^NI^200DOD^USDOD^A
      EDIPI_REGEX = /^\w+\^NI\^200DOD\^USDOD\^A$/.freeze
      # VBA_CORP_ID_REGEX, ex. 600043180^PI^200CORP^USVBA^A
      VBA_CORP_ID_REGEX = /^\w+\^PI\^200CORP\^USVBA\^A$/.freeze
      # IDME_ID_REGEX, ex. 54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A
      IDME_ID_REGEX = /^\w+\^PN\^200VIDM\^USDVA\^A$/.freeze
      # VHA_FACILITY_IDS_REGEX, ex. 123456^PI^200MHV^USVHA^A
      VHA_FACILITY_IDS_REGEX = /^\w+\^PI\^\w+\^USVHA\^\w+$/.freeze
      # CERNER_FACILITY_IDS_REGEX, ex. 123456^PI^200MHV^USVHA^C
      CERNER_FACILITY_IDS_REGEX = /^\w+\^PI\^\w+\^USVHA\^C$/.freeze
      # CERNER_ID_REGEX, ex. 123456^PI^200CRNR^USVHA^A
      CERNER_ID_REGEX = /^\w+\^PI\^200CRNR\^US\w+\^A$/.freeze
      # BIRLS_IDS_REGEX, ex. 123456^PI^200BRLS^USVBA^A
      BIRLS_IDS_REGEX = /^\w+\^PI\^200BRLS\^USVBA\^A$/.freeze
      # VET360_ID_REGEX, ex. 123456^PI^200VETS^USDVA^A
      VET360_ID_REGEX = /^\w+\^PI\^200VETS\^USDVA\^A$/.freeze
      ICN_ASSIGNING_AUTHORITY_ID = '^NI^200M^USVHA'

      # Defines the tokens we use to split identifiers or multiple ids in a single string
      IDENTIFIERS_SPLIT_TOKEN = '^'
      IDS_SPLIT_TOKEN = '|'
    end
  end
end
