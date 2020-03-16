# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'oidc/key_service'
require 'jwt'

class ExternalApiApplicationController < ApplicationController
  skip_before_action :validate_csrf_token!
  skip_after_action :set_csrf_cookie
end
