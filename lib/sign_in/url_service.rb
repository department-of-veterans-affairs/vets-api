# frozen_string_literal: true

module SignIn
  class URLService
    localhost_redirect = Settings.virtual_host_localhost || 'localhost'
    localhost_ip_redirect = Settings.virtual_host_localhost || '127.0.0.1'
    VIRTUAL_HOST_MAPPINGS = {
      'https://api.vets.gov' => { base_redirect: 'https://www.vets.gov' },
      'https://staging-api.vets.gov' => { base_redirect: 'https://staging.vets.gov' },
      'https://dev-api.vets.gov' => { base_redirect: 'https://dev.vets.gov' },
      'https://api.va.gov' => { base_redirect: 'https://www.va.gov' },
      'https://staging-api.va.gov' => { base_redirect: 'https://staging.va.gov' },
      'https://dev-api.va.gov' => { base_redirect: 'https://dev.va.gov' },
      'http://localhost:3000' => { base_redirect: "http://#{localhost_redirect}:3001" },
      'http://127.0.0.1:3000' => { base_redirect: "http://#{localhost_ip_redirect}:3001" }
    }.freeze

    def base_redirect_url
      VIRTUAL_HOST_MAPPINGS[current_host][:base_redirect]
    end

    def current_host
      uri = URI.parse(Settings.logingov.redirect_uri)
      URI.join(uri, '/').to_s.chop
    end
  end
end
