# frozen_string_literal: true

module VAForms
  class ApplicationController < ::ApplicationController
    service_tag 'lighthouse-forms'
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    before_action :require_gateway_origin

    def require_gateway_origin
      if Rails.env.production? && params[:source].blank? && Flipper.enabled?(:benefits_require_gateway_origin)
        raise Common::Exceptions::Unauthorized
      end
    end
  end
end
