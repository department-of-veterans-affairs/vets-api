# frozen_string_literal: true

require 'claims_evidence_api/exceptions/service'
require 'claims_evidence_api/exceptions/folder_identifier'

module ClaimsEvidenceApi
  module Exceptions
    include ClaimsEvidenceApi::Exceptions::Service
    include ClaimsEvidenceApi::Exceptions::FolderIdentifier

    # ClaimsEvidence API possible error codes
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html
    class VefsError < StandardError
      # rubocop:disable Layout/LineLength
      CURRENT_VERSION_NOT_FOUND = 'VEFSERR40402'          # Current Version not found for UUID %s.
      DATA_NOT_FOUND_FOR_CURRENT_VERSION = 'VEFSERR40403' # Requested data could not be found for current version of UUID %s
      DISABLED_IDENTIFIER = 'VEFSERR40059'                # Identifier %s is not enabled
      DOES_NOT_CONFORM_TO_SCHEMA = 'VEFSERR40001'         # Error message
      DUPLICATE_PROVIDERDATA_KEYS = 'VEFSERR40002'        # Duplicate key: providerData contained duplicate keys %s
      INVALID_EVALUATION_TYPE = 'VEFSERR50015'            # Error encountered processing - %s is not a valid filter evaluation type for %s
      INVALID_JWT = 'VEFSERR40009'                        # JWT provided does not contain expected claims, or contains invalid claim value(s).
      INVALID_MIMETYPE = 'VEFSERR41501'                   # File binary content contained magic bytes indicates mime type: %s which does not match accepted mime types: %s
      INVALID_RESPONSE = 'VEFSERR50050'                   # Invalid response found on payload.
      INVALID_REQUEST = 'VEFSERR40010'                    # Invalid request data.
      INVALID_X_EFOLDER_URI = 'VEFSERR40008'              # Header X-EFOLDER-URI contained invalid value %s
      JSON_DESERIALIZATION = 'VEFSERR50011'               # JSON deserialization error.
      JSON_SERIALIZATION = 'VEFSERR50010'                 # JSON serialization error.
      NO_RESULTS_RETURNED = 'VEFSERR50006'                # No results returned for %s.
      NOT_FOUND = 'VEFSERR40010'                          # Not found.
      NULL_RESPONSE = 'VEFSERR50051'                      # Null response found on payload.
      OPERATION_NOT_ENABLED = 'VEFSERR50102'              # Operation not enabled.
      PAYLOAD_VALIDATION = 'VEFSERR50008'                 # Payload invalid.
      RESOURCE_NOT_FOUND = 'VEFSERR40401'                 # Expected resource not found.
      UNABLE_TO_CONVERT = 'VEFSERR50012'                  # Unable to convert document from mime type %s to mime type %s
      UNABLE_TO_DETERMINE_MIMETYPE = 'VEFSERR50001'       # File binary content's mime type was unable to be determined. Accepted Type(s): %s
      UNABLE_TO_PERSIST_DATA = 'VEFSERR50003'             # Unknown error encountered saving data.
      UNABLE_TO_REMEDIATE_DATA = 'VEFSERR50013'           # Unknown error encountered remediating data.
      UNABLE_TO_RETRIEVE_PERSON = 'VEFSERR40302'          # Unable to retrieve folder of Type: %s using Identifier: %s.
      UNABLE_TO_RETRIEVE_USER = 'VEFSERR50006'            # Unknown error encountered retrieving user information.
      UNABLE_TO_RETRIEVE_VETERAN = 'VEFSERR40302'         # Unable to retrieve folder of Type: %s using Identifier: %s.
      UNABLE_TO_UPLOAD_DOCUMENT_CONTENT = 'VEFSERR50002'  # Unknown error encountered uploading content.
      UNABLE_TO_VERIFY_FOLDER = 'VEFSERR50014'            # Unable to confirm validity of folder with Type %s using Identifier Type %s.
      UNAUTHORIZED = 'VEFSERR40301'                       # Unauthorized
      UNKNOWN_ERROR = 'VEFSERR50009'                      # Unknown system error occurred.
      VALIDATE_INVALID_VALUE = 'VEFSERR40003'             # Key: %s contained invalid value(s) %s
      WRONG_MIMETYPE_EXTENSION = 'VEFSERR41502'           # File binary content contained magic bytes indicates mime type: %s which does not match filename extension: %s
      # rubocop:enable Layout/LineLength
    end
  end

  # end ClaimsEvidenceApi
end
