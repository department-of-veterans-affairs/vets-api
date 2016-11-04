# frozen_string_literal: true
module MHVLogging
  module API
    # This module defines the session actions
    module Sessions
      def get_session
        env = perform(:get, 'session', nil, auth_headers)
        req_headers = env.request_headers
        res_headers = env.response_headers
        # This session store inherits from Rx, therefore it is the same redis_store
        MHVLogging::ClientSession.new(user_id: req_headers['mhvCorrelationId'],
                                      expires_at: res_headers['expires'],
                                      token: res_headers['token'])
      end
    end
  end
end
