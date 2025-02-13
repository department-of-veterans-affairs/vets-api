# frozen_string_literal: true

def mock_acg(_scopes)
  VCR.use_cassette('claims_api/token_validation/v3/indicates_token_is_valid_sandbox') do
    VCR.use_cassette('claims_api/token_validation/v3/userinfo_sandbox') do
      profile = build(:mpi_profile, given_names: %w[abraham], family_name: 'lincoln', ssn: '796111863')
      profile_response = build(:find_profile_response, profile:)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)

      auth_header = { authorization: 'Bearer token', 'Content-Type': 'application/json' }
      yield(auth_header)
    end
  end
end

def mock_ccg(_scopes, vcr_options = {})
  VCR.use_cassette('claims_api/token_validation/v3/shows_token_is_valid', vcr_options) do
    auth_header = { authorization: 'Bearer token', 'Content-Type': 'application/json' }
    yield(auth_header)
  end
end

def mock_ccg_for_fine_grained_scope(scope_names)
  VCR.use_cassette('claims_api/token_validation/v3/shows_token_is_valid_with_fine_grained_scope',
                   erb: { scopes: scope_names }) do
    auth_header = { authorization: 'Bearer token', 'Content-Type': 'application/json' }
    yield(auth_header)
  end
end
