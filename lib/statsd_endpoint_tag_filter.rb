# frozen_string_literal: true

class StatsdEndpointTagFilter

  def self.redact(endpoint)
    # Regex for OIDs (excluding version numbers)
    oid_regex = /(\b\d+(\.\d+)+\b)/
    uuid_regex = /[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
    encoded_segment_regex = %r{[^/]*_5eusd(?:va|od)[^/]*}
    id_regex = /\b[a-f0-9]{5,}\b/
    institution_ids = /[\dA-Z]{8}/
    provider_ids = /Providers\(\d{10}\)/
    okta_users = %r{(?<user_path>api/v1/users/)\w*}
    digit = /(?<![a-zA-Z])(?<!v)-?\d+/  # Avoid matching numbers with preceding letters or 'v'
    contact_id = /\d{10}V\d{6}(%5ENI%5E200M%5EUSVHA)*/  # institution id's of form 111A2222 or 11A22222

    # Combined regex (OIDs OR UUIDs)
    redact_regex = Regexp.union(
      oid_regex,
      id_regex,
      uuid_regex,
      encoded_segment_regex,
      institution_ids,
      provider_ids,
      okta_users,
      digit,
      contact_id
    )
    # replace identifiers with 'xxx'
    endpoint.gsub(redact_regex, 'xxx').gsub(/x{4,}/, 'xxx')
  end
end
