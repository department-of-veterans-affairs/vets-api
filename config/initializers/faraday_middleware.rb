# frozen_string_literal: true

require 'common/client/middleware/request/remove_cookies'
require 'common/client/middleware/request/immutable_headers'
require 'hca/soap_parser'

Rails.application.reloader.to_prepare do
  Faraday::Middleware.register_middleware remove_cookies: Common::Client::Middleware::Request::RemoveCookies
  Faraday::Middleware.register_middleware immutable_headers: Common::Client::Middleware::Request::ImmutableHeaders

  Faraday::Response.register_middleware hca_soap_parser: HCA::SOAPParser
end

Faraday::Response::RaiseError.default_options = { include_request: false }
