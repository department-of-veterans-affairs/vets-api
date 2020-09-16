# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'aes_256_cbc_encryptor'

class BaseApplicationController < ActionController::API
  include ExceptionHandling
  include Headers
  include Instrumentation
  include Pundit
  include SentryLogging
  
  attr_reader :current_user
end
