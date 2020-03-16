# frozen_string_literal: true

# This module only gets mixed in to one place, but is that cleanest way to organize everything in one place related
# to this responsibility alone.
module CSRFProtection
  extend ActiveSupport::Concern
  include ActionController::RequestForgeryProtection
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
      value: form_authenticity_token,
      expires: 1.day.from_now,
      secure: true
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
