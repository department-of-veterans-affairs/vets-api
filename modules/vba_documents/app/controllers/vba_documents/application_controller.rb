# frozen_string_literal: true

module VBADocuments
  class ApplicationController < ::ApplicationController
    service_tag 'lighthouse-benefits-intake'
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    before_action :require_gateway_origin

    def require_gateway_origin
      if Rails.env.production? && params[:source].blank? && Flipper.enabled?(:benefits_require_gateway_origin)
        raise Common::Exceptions::Unauthorized
      end
    end

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'vba_documents' }
      Sentry.set_tags(source: 'vba_documents')
    end

    def consumer
      request.headers['X-Consumer-Username']
    end
  end
end
