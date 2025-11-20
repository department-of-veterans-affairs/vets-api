# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # DocumentTypes API
    # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Document%20Types
    class DocumentTypes < Base
      # @see #retrieve
      def self.get
        new.retrieve
      end

      # GET retrieve the list of document types
      # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/Document%20Types/getDocumentTypes
      def retrieve
        perform :get, 'documenttypes', {}
      end

      private

      # @see ClaimsEvidenceApi::Service::Base#endpoint
      def endpoint
        'documenttypes'
      end

      # end DocumentTypes
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
