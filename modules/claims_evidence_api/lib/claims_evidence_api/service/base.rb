# frozen_string_literal: true

require 'claims_evidence_api/configuration'
require 'claims_evidence_api/exceptions'
require 'claims_evidence_api/x_folder_uri'
require 'common/client/base'

module ClaimsEvidenceApi
  # Proxy Service for the ClaimsEvidence API
  #
  # @see https://depo-platform-documentation.scrollhelp.site/developer-docs/endpoint-monitoring
  # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html
  module Service
    # Base class for API
    class Base < Common::Client::Base
      configuration ClaimsEvidenceApi::Configuration

      include ClaimsEvidenceApi::Exceptions

      attr_reader :x_folder_uri

      # directly assign a folder identifier; value is split and sent through #x_folder_uri_set
      def x_folder_uri=(folder_identifier)
        folder_identifier = ClaimsEvidenceApi::XFolderUri.validate(folder_identifier)
        folder_type, identifier_type, id = folder_identifier.split(':', 3)
        x_folder_uri_set(folder_type, identifier_type, id)
      end

      # set the folder identifier that the file will be associated to
      # @see ClaimsEvidenceApi::XFolderUri#generate
      def x_folder_uri_set(folder_type, identifier_type, id)
        @x_folder_uri = ClaimsEvidenceApi::XFolderUri.generate(folder_type, identifier_type, id)
      end
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
