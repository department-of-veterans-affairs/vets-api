# frozen_string_literal: true

module SignIn
  module Constants
    module Statsd
      STATSD_SIS_AUTHORIZE_ATTEMPT_SUCCESS = 'api.sis.auth.success'
      STATSD_SIS_AUTHORIZE_ATTEMPT_FAILURE = 'api.sis.auth.failure'
      STATSD_SIS_CALLBACK_SUCCESS = 'api.sis.callback.success'
      STATSD_SIS_CALLBACK_FAILURE = 'api.sis.callback.failure'
      STATSD_SIS_TOKEN_SUCCESS = 'api.sis.token.success'
      STATSD_SIS_TOKEN_FAILURE = 'api.sis.token.failure'
      STATSD_SIS_REFRESH_SUCCESS = 'api.sis.refresh.success'
      STATSD_SIS_REFRESH_FAILURE = 'api.sis.refresh.failure'
      STATSD_SIS_REVOKE_SUCCESS = 'api.sis.revoke.success'
      STATSD_SIS_REVOKE_FAILURE = 'api.sis.revoke.failure'
      STATSD_SIS_INTROSPECT_SUCCESS = 'api.sis.introspect.success'
      STATSD_SIS_INTROSPECT_FAILURE = 'api.sis.introspect.failure'
    end
  end
end
