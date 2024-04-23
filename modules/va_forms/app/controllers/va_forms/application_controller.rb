# frozen_string_literal: true

module VAForms
  class ApplicationController < ::ApplicationController
    service_tag 'lighthouse-forms'
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    before_action :require_gateway_origin

    def require_gateway_origin
      raise Common::Exceptions::Unauthorized if Rails.env.production? \
        && (request.headers['X-Consumer-ID'].blank? || request.headers['X-Consumer-Username'].blank?) \
        && Flipper.enabled?(:benefits_require_gateway_origin)
    end
  end
end
