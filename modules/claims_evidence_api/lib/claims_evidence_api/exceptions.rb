# frozen_string_literal: true

module ClaimsEvidenceApi
  module Exceptions

    class UndefinedXFolderURI < StandardError; end
    class FileNotFound < StandardError; end

    class VefsError < StandardError
      INVALID_JWT = 'VEFSERR40009'                        # JWT provided does not contain expected claims, or contains invalid claim value(s).
      INVLAID_REQUEST = 'VEFSERR40010'                    # Invalid request data.
      INVALID_X_EFOLDER_URI = 'VEFSERR40008'              # Header X-EFOLDER-URI contained invalid value %s
      UNABLE_TO_VERIFY_FOLDER = 'VEFSERR50014'            # Unable to confirm validity of folder with Type %s using Identifier Type %s.
      DOES_NOT_CONFORM_TO_SCHEMA = 'VEFSERR40001'         # Error message
      VALIDATE_INVALID_VALUE = 'VEFSERR40003'             # Key: %s contained invalid value(s) %s
      UNABLE_TO_RETRIEVE_PERSON = 'VEFSERR40302'          # Unable to retrieve folder of Type: %s using Identifier: %s.
      UNABLE_TO_RETRIEVE_VETERAN = 'VEFSERR40302'         # Unable to retrieve folder of Type: %s using Identifier: %s.
      UNAUTHORIZED = 'VEFSERR40301'                       # Unauthorized
      UNABLE_TO_RETRIEVE_USER = 'VEFSERR50006'            # Unknown error encountered retrieving user information.
      NO_RESULTS_RETURNED = 'VEFSERR50006'                # No results returned for %s.
      INVALID_EVALUATION_TYPE = 'VEFSERR50015'            # Error encountered processing - %s is not a valid filter evaluation type for %s
      NULL_RESPONSE = 'VEFSERR50051'                      # Null response found on payload.
      UNKNOWN_ERROR = 'VEFSERR50009'                      # Unknown system error occurred.
      JSON_DESERIALIZATION = 'VEFSERR50011'               # JSON deserialization error.
      JSON_SERIALIZATION = 'VEFSERR50010'                 # JSON serialization error.
      OPERATION_NOT_ENABLED = 'VEFSERR50102'              # Operation not enabled.
      DUPLICATE_PROVIDERDATA_KEYS = 'VEFSERR40002'        # Duplicate key: providerData contained duplicate keys %s
      DISABLED_IDENTIFIER = 'VEFSERR40059'                # Identifier %s is not enabled
      NOT_FOUND = 'VEFSERR40010'                          # Not found.
      INVALID_MIMETYPE = 'VEFSERR41501'                   # File binary content contained magic bytes indicates mime type: %s which does not match accepted mime types: %s
      WRONG_MIMETYPE_EXTENSION = 'VEFSERR41502'           # File binary content contained magic bytes indicates mime type: %s which does not match filename extension: %s
      UNABLE_TO_DETERMINE_MIMETYPE = 'VEFSERR50001'       # File binary content's mime type was unable to be determined. Accepted Type(s): %s
      UNABLE_TO_UPLOAD_DOCUMENT_CONTENT = 'VEFSERR50002'  # Unknown error encountered uploading content.
      UNABLE_TO_PERSIST_DATA = 'VEFSERR50003'             # Unknown error encountered saving data.
      UNABLE_TO_CONVERT = 'VEFSERR50012'                  # Unable to convert document from mime type %s to mime type %s
      CURRENT_VERSION_NOT_FOUND = 'VEFSERR40402'          # Current Version not found for UUID %s.
      UNABLE_TO_REMEDIATE_DATA = 'VEFSERR50013'           # Unknown error encountered remediating data.
      INVALID_RESPONSE = 'VEFSERR50050'                   # Invalid response found on payload.
      RESOURCE_NOT_FOUND = 'VEFSERR40401'                 # Expected resource not found.
      PAYLOAD_VALIDATION = 'VEFSERR50008'                 # Payload invalid.
      DATA_NOT_FOUND_FOR_CURRENT_VERSION = 'VEFSERR40403' # Requested data could not be found for current version of UUID %s
    end
  end

  # end ClaimsEvidenceApi
end
