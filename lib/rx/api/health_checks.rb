# frozen_string_literal: true
module Rx
  module API
    # This module defines the session actions
    module HealthChecks
      def check_core
        _env = perform(:get, '', nil, auth_headers)
      end
    end
  end
end
