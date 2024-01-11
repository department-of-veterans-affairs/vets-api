# frozen_string_literal: true

module VBADocuments
  class ApplicationController < ::ApplicationController
    service_tag 'lighthouse-benefits-intake'
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'vba_documents' }
      Sentry.set_tags(source: 'vba_documents')
    end

    def consumer
      request.headers['X-Consumer-Username']
    end
  end
end
