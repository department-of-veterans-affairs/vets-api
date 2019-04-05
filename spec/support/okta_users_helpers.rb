# frozen_string_literal: true

def with_okta_configured(&block)
  with_settings(
    Settings.oidc,
    auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/openid-configuration',
    issuer: 'https://example.com/oauth2/default',
    audience: 'api://default',
    base_api_url: 'https://example.com/',
    base_api_token: 'token'
  ) do
    VCR.use_cassette('okta/metadata') do
      yield block
    end
  end
end

def okta_jwt(scopes)
  [{
    'ver' => 1,
    'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
    'iss' => 'https://example.com/oauth2/default',
    'aud' => 'api://default',
    'iat' => Time.current.utc.to_i,
    'exp' => Time.current.utc.to_i + 3600,
    'cid' => '0oa1c01m77heEXUZt2p7',
    'uid' => '00u1zlqhuo3yLa2Xs2p7',
    'scp' => scopes,
    'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
  }, {
    'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
    'alg' => 'RS256'
  }]
end

def with_okta_user(scopes)
  token = 'token'
  auth_header = { 'Authorization' => "Bearer #{token}" }
  user = create(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3))

  allow(JWT).to receive(:decode).and_return(okta_jwt(scopes))
  Session.create(uuid: user.uuid, token: token)
  with_okta_configured do
    yield(auth_header)
  end
end
