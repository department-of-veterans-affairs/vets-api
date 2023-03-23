# frozen_string_literal: true

def with_okta_configured(&block)
  with_settings(
    Settings.oidc,
    auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/openid-configuration',
    issuer: 'https://example.com/oauth2/default',
    issuer_prefix: 'https://example.com/oauth2',
    audience: 'api://default',
    base_api_url: 'https://example.com/',
    base_api_token: 'token'
  ) do
    with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
      VCR.use_cassette('okta/metadata') do
        VCR.use_cassette('okta/openid-user') do
          yield block
        end
      end
    end
  end
end

def with_okta_okta_and_issued_url_configured(&block)
  with_settings(
    Settings.oidc,
    auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/openid-configuration',
    issuer: 'https://example.com/oauth2/default',
    issued_url: 'https://example.com/oauth2/default',
    issuer_prefix: 'https://example.com/oauth2',
    audience: 'api://default',
    base_api_url: 'https://example.com/',
    base_api_token: 'token'
  ) do
    with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
      VCR.use_cassette('okta/metadata') do
        VCR.use_cassette('okta/openid-user') do
          yield block
        end
      end
    end
  end
end

def with_okta_profile_configured(&block)
  with_settings(
    Settings.oidc,
    auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/openid-configuration',
    issuer: 'https://example.com/oauth2/default',
    issuer_prefix: 'https://example.com/oauth2',
    audience: 'api://default',
    base_api_url: 'https://example.com/',
    base_api_token: 'token'
  ) do
    with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
      VCR.use_cassette('okta/metadata') do
        yield block
      end
    end
  end
end

def with_okta_profile_with_uuid_configured(&block)
  with_settings(
    Settings.oidc,
    auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/openid-configuration',
    issuer: 'https://example.com/oauth2/default',
    issuer_prefix: 'https://example.com/oauth2',
    audience: 'api://default',
    base_api_url: 'https://example.com/',
    base_api_token: 'token'
  ) do
    with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
      VCR.use_cassette('okta/metadata-ssoe') do
        yield block
      end
    end
  end
end

def with_okta_profile_with_ial_aal_configured(&block)
  with_settings(
    Settings.oidc,
    auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/openid-configuration',
    issuer: 'https://example.com/oauth2/default',
    issuer_prefix: 'https://example.com/oauth2',
    audience: 'api://default',
    base_api_url: 'https://example.com/',
    base_api_token: 'token'
  ) do
    with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
      VCR.use_cassette('okta/openid-user-login-gov') do
        yield block
      end
    end
  end
end

def vcr_cassette(open_id_cassette, &block)
  VCR.use_cassette('okta/metadata') do
    VCR.use_cassette(open_id_cassette) do
      yield block
    end
  end
end

def with_ssoi_profile_configured(&block)
  with_settings(
    Settings.oidc,
    auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/openid-configuration',
    issuer: 'https://example.com/oauth2/default',
    issuer_prefix: 'https://example.com/oauth2',
    audience: 'api://default',
    base_api_url: 'https://example.com/',
    base_api_token: 'token'
  ) do
    with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
      VCR.use_cassette('okta/metadata') do
        VCR.use_cassette('okta/ssoi-user') do
          yield block
        end
      end
    end
  end
end

def with_ssoi_charon_configured(&)
  with_settings(
    Settings.oidc,
    auth_server_metadata_url: 'https://example.com/oauth2/default/.well-known/openid-configuration',
    issuer_prefix: 'https://example.com/oauth2',
    audience: 'api://default'
  ) do
    with_oidc_charon_configured(&)
  end
end

def with_oidc_charon_configured(&)
  with_settings(Settings.oidc.isolated_audience, default: 'api://default') do
    with_settings(
      Settings.oidc.charon,
      enabled: true,
      audience: 'https://example.com/xxxxxxservices/xxxxx',
      endpoint: 'http://example.com/services/charon'
    ) do
      with_settings(
        Settings.oidc, smart_launch_url: 'http://example.com/smart/launch'
      ) do
        vcr_cassette('okta/openid-user-charon', &)
      end
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
  Session.create(uuid: user.uuid, token: Digest::SHA256.hexdigest(token.to_s))
  with_okta_configured do
    yield(auth_header)
  end
end
