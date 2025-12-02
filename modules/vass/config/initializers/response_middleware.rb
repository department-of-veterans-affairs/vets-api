# frozen_string_literal: true

# This initializer loads the VASS response middleware and registers it with Faraday.
# It runs after Rails initialization to ensure all dependencies (like common/exceptions) are available.

require 'vass/response_middleware'

# Register custom Faraday middleware for VASS error handling
Faraday::Response.register_middleware(vass_errors: Vass::ResponseMiddleware)
