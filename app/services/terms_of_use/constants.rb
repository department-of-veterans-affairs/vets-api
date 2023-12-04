# frozen_string_literal: true

module TermsOfUse
  module Constants
    PROVISIONER_COOKIE_NAME = 'CERNER_CONSENT'
    PROVISIONER_COOKIE_VALUE = 'ACCEPTED'
    PROVISIONER_COOKIE_PATH = '/'
    PROVISIONER_COOKIE_EXPIRATION = 2.minutes
    PROVISIONER_COOKIE_DOMAIN = '.va.gov'
  end
end
