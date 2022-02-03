# frozen_string_literal: true

module VBADocuments
  class ApplicationController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'vba_documents' }
      Raven.tags_context(source: 'vba_documents')
    end

    def consumer
      request.headers['X-Consumer-Username']
    end
  end
end
