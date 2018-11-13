# frozen_string_literal: true

Faraday::Middleware.register_middleware remove_cookies: Common::Client::Middleware::Request::RemoveCookies
Faraday::Middleware.register_middleware immutable_headers: Common::Client::Middleware::Request::ImmutableHeaders
Faraday::Request.register_middleware rescue_timeout: Common::Client::Middleware::Request::RescueTimeout
Faraday::Response.register_middleware hca_soap_parser: HCA::SOAPParser
Faraday::Response.register_middleware rescue_timeout: Common::Client::Middleware::Response::RescueTimeout
