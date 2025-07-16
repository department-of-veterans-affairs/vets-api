# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service
    # DocumentTypes API
    class DocumentTypes < Base
      # @see #retrieve
      def self.get
        new.retrieve
      end

      # GET retrieve the list of document types
      # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html#/Document%20Types/getDocumentTypes
      def retrieve
        perform :get, 'documenttypes', {}
      end

      # end DocumentTypes
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
