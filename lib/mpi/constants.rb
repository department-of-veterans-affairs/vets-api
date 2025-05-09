# frozen_string_literal: true

module MPI
  module Constants
    ADD_PERSON = 'PRPA_IN201301UV02'
    UPDATE_PROFILE = 'PRPA_IN201302UV02'
    FIND_PROFILE = 'PRPA_IN201305UV02'

    # MPI Service response error codes
    NOT_FOUND = 'MVI_404'
    ERROR = 'MVI_502'
    DUPLICATE_ERROR = 'MVI_502_DUP'
    OUTAGE_EXCEPTION = 'MVI_503'
    CONNECTION_FAILED = 'MVI_504'

    SEARCH_TYPES = [CORRELATION = 'MVI.COMP1',
                    CORRELATION_WITH_ICN_HISTORY = 'MVI.COMP2',
                    CORRELATION_WITH_RELATIONSHIP_DATA = 'MVI.COMP1.RMS'].freeze

    IDME_IDENTIFIER = '200VIDM'
    LOGINGOV_IDENTIFIER = '200VLGN'
    DSLOGON_IDENTIFIER = '200DOD'

    IDME_FULL_IDENTIFIER = 'PN^200VIDM^USDVA^A'
    LOGINGOV_FULL_IDENTIFIER = 'PN^200VLGN^USDVA^A'
    MHV_FULL_IDENTIFIER = 'PI^200MH^USVHA^A'
    DSLOGON_FULL_IDENTIFIER = 'NI^200DOD^USDOD^A'

    ACTIVE_VHA_IDENTIFIER = 'USVHA^A'

    DOD_ROOT_OID = '2.16.840.1.113883.3.42.10001.100001.12'
    VA_ROOT_OID = '2.16.840.1.113883.4.349'
    AS_AGENT_DEVICE_ID_ROOT_OID = '2.16.840.1.113883.3.933'

    FIND_PROFILE_CONTROL_ACT_PROCESS = 'PRPA_TE201305UV02'

    ADD_PERSON_PROXY_TYPE = 'add_person_proxy'
    ADD_PERSON_IMPLICIT_TYPE = 'add_person_implicit'
    UPDATE_PROFILE_TYPE = 'update_profile'
    FIND_PROFILE_TYPE = 'find_profile'
    FIND_PROFILE_BY_IDENTIFIER_TYPE = 'find_profile_by_identifier'
    FIND_PROFILE_BY_EDIPI_TYPE = 'find_profile_by_edipi'
    FIND_PROFILE_BY_ATTRIBUTES_TYPE = 'find_profile_by_attributes'
    FIND_PROFILE_BY_ATTRIBUTES_ORCH_SEARCH_TYPE = 'find_profile_by_attributes_orch_search'
    FIND_PROFILE_BY_FACILITY_TYPE = 'find_profile_by_facility'

    QUERY_IDENTIFIERS = [ICN = 'ICN', IDME_UUID = 'idme', LOGINGOV_UUID = 'logingov', MHV_UUID = 'mhv'].freeze
  end
end
