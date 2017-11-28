# frozen_string_literal: true
Faraday::Middleware.register_middleware remove_cookies: Common::Client::Middleware::Request::RemoveCookies
