# frozen_string_literal: true

module AppealsApi
  module GatewayOriginCheck
    extend ActiveSupport::Concern

    included do
      prepend_before_action :require_gateway_origin
    end

    def require_gateway_origin
      raise Common::Exceptions::Unauthorized if Rails.env.production? \
        && (request.headers['X-Consumer-ID'].blank? || request.headers['X-Consumer-Username'].blank?) \
        && Flipper.enabled?(:benefits_require_gateway_origin)
    end
  end
end
