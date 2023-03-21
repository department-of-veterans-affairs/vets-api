# frozen_string_literal: true

module Identity
  module Parsers
    module GCIdsConstants
      # Originating IDs, defines what underlying system the ID has been sourced from
      VA_ROOT_OID = '2.16.840.1.113883.4.349'
      DOD_ROOT_OID = '2.16.840.1.113883.3.42.10001.100001.12'

      # The follow set of regex match each full ID format and extract the specific ID value from each
      # They tend to follow the format: <id>^<id_type>^<assigning_facility>^<assigning_authority>^<id_state>

      # ICN_REGEX, ex. 16701377^NI^200M^USVHA^A
      ICN_REGEX = /^\w+\^NI\^200M\^USVHA\^\w+$/

      # PERMANENT_ICN_REGEX, ex. 1008830476V316605^NI^200M^USVHA^P
      PERMANENT_ICN_REGEX = /^\w+\^NI\^200M\^USVHA\^P$/

      # SEC_ID_REGEX, ex. 1008830476^PN^200PROV^USDVA^A
      SEC_ID_REGEX = /^\w+\^PN\^200PROV\^USDVA\^A$/

      # MHV_IDS_REGEX, ex. 123456^PI^200MHV^USVHA^P
      MHV_IDS_REGEX = /^\w+\^PI\^200MH.{0,1}\^\w+\^\w+$/

      # ACTIVE_MHV_IDS_REGEX, ex. 123456^PI^200MHV^USVHA^A
      ACTIVE_MHV_IDS_REGEX = /^\w+\^PI\^200MH.{0,1}\^\w+\^A$/

      # MHV_IEN_REGEX, ex. 123456^PI^200MHS^USVHA^A
      MHV_IEN_REGEX = /^\w+\^PI\^200MHS\^USVHA\^A$/

      # EDIPI_REGEX, ex. 2107307560^NI^200DOD^USDOD^A
      EDIPI_REGEX = /^\w+\^NI\^200DOD\^USDOD\^A$/

      # VBA_CORP_ID_REGEX, ex. 600043180^PI^200CORP^USVBA^A
      VBA_CORP_ID_REGEX = /^\w+\^PI\^200CORP\^USVBA\^A$/

      # IDME_ID_REGEX, ex. 54e78de6140d473f87960f211be49c08^PN^200VIDM^USDVA^A
      IDME_ID_REGEX = /^\w+\^PN\^200VIDM\^USDVA\^A$/

      # LOGINGOV_ID_REGEX, ex. aa478abc-e494-4af1-9f87-d002f8fe1cda^PN^200VLGN^USDVA^A
      LOGINGOV_ID_REGEX = /^[\w-]+\^PN\^200VLGN\^USDVA\^A$/

      # VHA_FACILITY_IDS_REGEX, ex. 123456^PI^200MHV^USVHA^A
      VHA_FACILITY_IDS_REGEX = /^\w+\^PI\^\w+\^USVHA\^\w+$/

      # CERNER_FACILITY_IDS_REGEX, ex. 123456^PI^200MHV^USVHA^C
      CERNER_FACILITY_IDS_REGEX = /^\w+\^PI\^\w+\^USVHA\^C$/

      # CERNER_ID_REGEX, ex. 123456^PI^200CRNR^USVHA^A
      CERNER_ID_REGEX = /^\w+\^PI\^200CRNR\^US\w+\^A$/

      # BIRLS_IDS_REGEX, ex. 123456^PI^200BRLS^USVBA^A
      BIRLS_IDS_REGEX = /^\w+\^PI\^200BRLS\^USVBA\^A$/

      # VET360_ID_REGEX, ex. 123456^PI^200VETS^USDVA^A
      VET360_ID_REGEX = /^\w+\^PI\^200VETS\^USDVA\^A$/

      ICN_ASSIGNING_AUTHORITY_ID = '^NI^200M^USVHA'

      # Defines the tokens we use to split identifiers or multiple ids in a single string
      IDENTIFIERS_SPLIT_TOKEN = '^'
      IDS_SPLIT_TOKEN = '|'

      # Defines the ids we will attempt to parse and map in a parse_xml_gcids/parse_string_gcids call
      ID_MAPPINGS = {
        icn: { regex: PERMANENT_ICN_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        sec_id: { regex: SEC_ID_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        edipi: { regex: EDIPI_REGEX, root_oid: DOD_ROOT_OID, type: :single_id },
        edipis: { regex: EDIPI_REGEX, root_oid: DOD_ROOT_OID, type: :multiple_ids },
        vba_corp_id: { regex: VBA_CORP_ID_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        vba_corp_ids: { regex: VBA_CORP_ID_REGEX, root_oid: VA_ROOT_OID, type: :multiple_ids },
        idme_id: { regex: IDME_ID_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        logingov_id: { regex: LOGINGOV_ID_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        cerner_id: { regex: CERNER_ID_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        vet360_id: { regex: VET360_ID_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        birls_id: { regex: BIRLS_IDS_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        mhv_ids: { regex: MHV_IDS_REGEX, root_oid: VA_ROOT_OID, type: :multiple_ids },
        mhv_ien: { regex: MHV_IEN_REGEX, root_oid: VA_ROOT_OID, type: :single_id },
        mhv_iens: { regex: MHV_IEN_REGEX, root_oid: VA_ROOT_OID, type: :multiple_ids },
        active_mhv_ids: { regex: ACTIVE_MHV_IDS_REGEX, root_oid: VA_ROOT_OID, type: :multiple_ids },
        birls_ids: { regex: BIRLS_IDS_REGEX, root_oid: VA_ROOT_OID, type: :multiple_ids },
        vha_facility_ids: { regex: VHA_FACILITY_IDS_REGEX, root_oid: VA_ROOT_OID, type: :facility },
        cerner_facility_ids: { regex: CERNER_FACILITY_IDS_REGEX, root_oid: VA_ROOT_OID, type: :facility },
        icn_with_aaid: { regex: PERMANENT_ICN_REGEX, root_oid: VA_ROOT_OID, type: :icn_with_aaid },
        vha_facility_hash: { regex: VHA_FACILITY_IDS_REGEX, root_oid: VA_ROOT_OID, type: :facility_to_ids }
      }.freeze
    end
  end
end
