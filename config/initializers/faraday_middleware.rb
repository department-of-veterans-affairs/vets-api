# frozen_string_literal: true
Faraday::Middleware.register_middleware remove_cookies: Common::Client::Middleware::Request::RemoveCookies
Faraday::Adapter.register_middleware net_http_header_patch: -> { Faraday::Adapter::NetHttpHeaderPatch }
