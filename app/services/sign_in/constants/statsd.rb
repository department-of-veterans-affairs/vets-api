# frozen_string_literal: true

module SignIn
  module Constants
    module Statsd
      STATSD_SIS_AUTHORIZE_SUCCESS = 'api.sis.auth.success'
      STATSD_SIS_AUTHORIZE_FAILURE = 'api.sis.auth.failure'
      STATSD_SIS_AUTHORIZE_SSO_SUCCESS = 'api.sis.auth_sso.success'
      STATSD_SIS_AUTHORIZE_SSO_FAILURE = 'api.sis.auth_sso.failure'
      STATSD_SIS_AUTHORIZE_SSO_REDIRECT = 'api.sis.auth_sso.redirect'
      STATSD_SIS_CALLBACK_SUCCESS = 'api.sis.callback.success'
      STATSD_SIS_CALLBACK_FAILURE = 'api.sis.callback.failure'
      STATSD_SIS_TOKEN_SUCCESS = 'api.sis.token.success'
      STATSD_SIS_TOKEN_FAILURE = 'api.sis.token.failure'
      STATSD_SIS_REFRESH_SUCCESS = 'api.sis.refresh.success'
      STATSD_SIS_REFRESH_FAILURE = 'api.sis.refresh.failure'
      STATSD_SIS_REVOKE_SUCCESS = 'api.sis.revoke.success'
      STATSD_SIS_REVOKE_FAILURE = 'api.sis.revoke.failure'
      STATSD_SIS_LOGOUT_SUCCESS = 'api.sis.logout.success'
      STATSD_SIS_LOGOUT_FAILURE = 'api.sis.logout.failure'
      STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS = 'api.sis.revoke_all_sessions.success'
      STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE = 'api.sis.revoke_all_sessions.failure'
    end
  end
end
