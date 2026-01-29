# frozen_string_literal: true

module SignIn
  module Constants
    module ErrorCode
      IDME_VERIFICATION_DENIED = '001'
      GENERIC_EXTERNAL_ISSUE = '007'
      LOGINGOV_VERIFICATION_DENIED = '009'
      MULTIPLE_MHV_IEN = '101'
      MULTIPLE_EDIPI = '102'
      MULTIPLE_CORP_ID = '106'
      MPI_LOCKED_ACCOUNT = '107'
      MHV_UNVERIFIED_BLOCKED = '108'
      SSN_ATTRIBUTE_MISMATCH = '113'
      INVALID_REQUEST = '400'
    end
  end
end
