# frozen_string_literal: true

Faraday::Middleware.register_middleware remove_cookies: Common::Client::Middleware::Request::RemoveCookies
Faraday::Middleware.register_middleware immutable_headers: Common::Client::Middleware::Request::ImmutableHeaders
Faraday::Middleware.register_middleware rescue_timeout: Common::Client::Middleware::Request::RescueTimeout
