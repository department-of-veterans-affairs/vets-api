# frozen_string_literal: true

require_relative 'service_account_authorization_context'

# Shared contexts
require_relative 'shared_contexts/authorize/setup'
require_relative 'shared_contexts/authorize/client_state_handling'

require_relative 'shared_contexts/callback/setup'
require_relative 'shared_contexts/callback/state_jwt_setup'

# Shared examples
require_relative 'shared_examples/authorize/api_error_response'
require_relative 'shared_examples/authorize/error_response'
require_relative 'shared_examples/authorize/successful_response'

require_relative 'shared_examples/callback/api_error_response'
require_relative 'shared_examples/callback/error_response'
