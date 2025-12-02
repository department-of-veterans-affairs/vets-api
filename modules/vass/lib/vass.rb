# frozen_string_literal: true

require 'vass/engine'
require 'vass/errors'
require 'vass/response_middleware'

module Vass
  # Register custom Faraday middleware for VASS error handling
  Faraday::Response.register_middleware(vass_errors: Vass::ResponseMiddleware)
end
