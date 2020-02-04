# frozen_string_literal: true

RSpec::Matchers.define :be_an_idme_saml_url do |expected_url_partial|
  match do |actual_url|
    # Use the URI library to parse the string, returning false if this fails.
    query_params = CGI.parse(URI.parse(actual_url).query)
    relay_state_params = query_params['RelayState'].present? ? JSON.parse(query_params['RelayState']&.first) : nil
    other_params = Hash[query_params.except('RelayState', 'SAMLRequest').map { |k, v| [k, v.first] }]
    values_match?(Regexp.new(Regexp.escape(expected_url_partial)), actual_url) &&
      (relay_state_params.present? ? values_match?(relay_state_params, @relay_state_params) : true) &&
      (other_params.present? ? values_match?(other_params, @other_params) : true)
  rescue URI::InvalidURIError
    false
  end

  chain :with_relay_state do |relay_state_params|
    @relay_state_params = relay_state_params
  end

  chain :with_params do |other_params|
    @other_params = other_params
  end

  diffable
end
