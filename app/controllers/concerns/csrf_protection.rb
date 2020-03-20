# frozen_string_literal: true

# `vets-api` operates as an API for our frontend, `vets-website`
# Since our frontend content is not rendered by the server, Rails' `protect_from_forgery` will not work.
# Still, our frontend provides form submissions for our end users.  Many of these forms do not require authentication
# CSRF proctection is still needed.  This module provides that protection following the same basic pattern
# that is used by Rails' `protect_from_forgery`
# Whereas `protect_from_forgery` uses `session` and hidden form fields, we are using `cookies` and request headers.
module CSRFProtection
  extend ActiveSupport::Concern
  include ActionController::Cookies

  included do
    before_action :validate_csrf_token!, if: lambda {
      ActionController::Base.allow_forgery_protection && request.method != 'GET'
    }
    after_action :set_csrf_cookie
  end

  protected

  def set_csrf_cookie
    cookies['X-CSRF-Token'] ||= {
      value: SecureRandom.base64(32),
      domain: :all,
      secure: Rails.env.production?
    }
  end

  def validate_csrf_token!
    if request.headers['X-CSRF-Token'].nil? || request.headers['X-CSRF-Token'] != cookies['X-CSRF-Token']
      # raise ActionController::InvalidAuthenticityToken

      # for now we are just logging when there's no CSRF protection
      # when this is going to be enforced return a meaningful error (and turn up logging level)
      log_message_to_sentry('Request susceptible to CSRF', :info, controller: self.class, action: action_name)
    end
  end
end
