# frozen_string_literal: true

module StringHelpers
  extend Gem::Text

  module_function

  def capitalize_only(str)
    str.slice(0, 1).capitalize + str.slice(1..-1)
  end

  def mask_sensitive(string)
    string&.gsub(/.(?=.{4})/, '*')
  end

  def hyphenated_ssn(ssn)
    return if ssn.blank?

    "#{ssn[0..2]}-#{ssn[3..4]}-#{ssn[5..8]}"
  end

  def heuristics(str_a, str_b)
    {
      length: [str_a.length, str_b.length],
      only_digits: [str_a.scan(/^\d+$/).any?, str_b.scan(/^\d+$/).any?],
      encoding: [str_a.encoding.to_s, str_b.encoding.to_s],
      levenshtein_distance: levenshtein_distance(str_a, str_b)
    }
  end

  def filtered_endpoint_tag(path)
    # replace identifiers with 'xxx'
    # this nasty-looking regex attempts to cover:
    # * (possibly negative) digit identifiers
    # * uuid's with or without dashes
    # * institution id's of form 111A2222 or 11A22222
    digit = /-?\d+/
    contact_id = /\d{10}V\d{6}(%5ENI%5E200M%5EUSVHA)*/
    uuids = /[a-fA-F0-9]{8}(-?[a-fA-F0-9]{4}){3}-?[a-fA-F0-9]{12}/
    institution_ids = /[\dA-Z]{8}/
    provider_ids = /Providers\(\d{10}\)/
    okta_users = %r{(?<user_path>api/v1/users/)\w*}
    r = %r{
      (?<first_slash>/)
      (#{okta_users} |#{digit} |#{contact_id} |#{uuids} |#{institution_ids} |#{provider_ids})
      (?<ending_slash>/|$)
    }x

    # replace  ids sent in the endpoint with 'xxx'
    rslt = path.gsub(r) do
      "#{$LAST_MATCH_INFO[:first_slash]}#{$LAST_MATCH_INFO[:user_path]}xxx#{$LAST_MATCH_INFO[:ending_slash]}"
    end

    filter_misc_endpoints(rslt)
  end

  def filter_misc_endpoints(rslt)
    # for endpoints of type '/cce/v1/patients/xxx/eligibility/<specialty>' replace <specialty> with zzz and
    # for endpoints of type '/facilities/v2/facilities/<id>' replace <id> with xxx
    # for endpoints of type '/vaos/v1/locations/<id>/clinics' replace <id> with xxx
    # for partial error responses, replace the trace ids with common label <id>
    # to provide better grouping in grafana
    case rslt
    when %r{/cce/v1/patients/xxx/eligibility/}
      "#{$LAST_MATCH_INFO}zzz"
    when %r{/facilities/v2/facilities/}
      "#{$LAST_MATCH_INFO}xxx"
    when /Could not get appointments from VistA Scheduling Service /
      "#{$LAST_MATCH_INFO}<id>"
    when %r{/vaos/v1/locations/[0-9A-Z]+/clinics$}
      '/vaos/v1/locations/xxx/clinics'
    else
      rslt
    end
  end
end
