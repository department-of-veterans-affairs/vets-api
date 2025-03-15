# frozen_string_literal: true

class StatsdEndpointTagFilter
  OID_REGEX = /(\b\d+(\.\d+)+\b)/
  UUID_REGEX = /[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
  ENCODED_SEGMENT_REGEX = %r{[^/]*_5eusd(?:va|od)[^/]*}
  ID_REGEX = /\b[a-f0-9]{5,}\b/
  INSTITUTION_IDS = /[\dA-Z]{8}/
  PROVIDER_IDS = /Providers\(\d{10}\)/
  OKTA_USERS = %r{(?<user_path>api/v1/users/)\w*}
  DIGIT = /(?<![a-zA-Z])(?<!v)-?\d+/ # Avoid matching numbers with preceding letters or 'v'
  CONTACT_ID = /\d{10}V\d{6}(%5ENI%5E200M%5EUSVHA)*/ # institution id's of form 111A2222 or 11A22222

  # Combined regex (OIDs OR UUIDs)
  REDACT_REGEX = Regexp.union(
    OID_REGEX,
    ID_REGEX,
    UUID_REGEX,
    ENCODED_SEGMENT_REGEX,
    INSTITUTION_IDS,
    PROVIDER_IDS,
    OKTA_USERS,
    DIGIT,
    CONTACT_ID
  )

  def self.redact(endpoint)
    # Replace identifiers with 'xxx'
    endpoint.gsub(REDACT_REGEX, 'xxx').gsub(/x{4,}/, 'xxx')
  end
end
