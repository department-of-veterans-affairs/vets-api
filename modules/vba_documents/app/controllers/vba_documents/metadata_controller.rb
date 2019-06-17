# frozen_string_literal: true

module VBADocuments
  class MetadataController < ::ApplicationController
    skip_before_action(:authenticate)

    def index
      render json: {
        meta: {
          versions: [
            {
              version: '1.0.0',
              internal_only: false,
              status: VERSION_STATUS[:draft],
              path: '/services/vba_documents/docs/v1/api',
              healthcheck: '/services/vba_documents/v1/healthcheck'
            },
            {
              version: '0.0.1',
              internal_only: false,
              status: VERSION_STATUS[:current],
              path: '/services/vba_documents/docs/v0/api',
              healthcheck: '/services/vba_documents/v0/healthcheck'
            }
          ]
        }
      }
    end
  end
end
