# frozen_string_literal: true

module MPI
  module Constants
    # The MVI Service SOAP operations vets.gov has access toto three MVI endpoints:
    # * PRPA_IN201301UV02 (TODO(AJD): Add Person)
    # * PRPA_IN201302UV02 (TODO(AJD): Update Profile)
    # * PRPA_IN201305UV02 (aliased as .find_profile)
    ADD_PERSON = 'PRPA_IN201301UV02'
    UPDATE_PROFILE = 'PRPA_IN201302UV02'
    FIND_PROFILE = 'PRPA_IN201305UV02'

    # MPI Service response error codes
    NOT_FOUND = 'MVI_404'
    ERROR = 'MVI_502'
    DUPLICATE_ERROR = 'MVI_502_DUP'
    OUTAGE_EXCEPTION = 'MVI_503'
    CONNECTION_FAILED = 'MVI_504'

    # MPI Service Search types, CORRELATION refers to standard query with full user data
    CORRELATION = 'MVI.COMP1'
    CORRELATION_WITH_ICN_HISTORY = 'MVI.COMP2'
    CORRELATION_WITH_RELATIONSHIP_DATA = 'MVI.COMP1.RMS'

    IDME_IDENTIFIER = '200VIDM'
    LOGINGOV_IDENTIFIER = '200VLGN'
    DSLOGON_IDENTIFIER = '200DOD'

    IDME_FULL_IDENTIFIER = 'PN^200VIDM^USDVA'
    LOGINGOV_FULL_IDENTIFIER = 'PN^200VLGN^USDVA'
    DSLOGON_FULL_IDENTIFIER = 'NI^200DOD^USDOD'
  end
end
