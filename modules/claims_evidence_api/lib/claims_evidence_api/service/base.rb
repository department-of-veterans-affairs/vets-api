# frozen_string_literal: true

require 'claims_evidence_api/configuration'
require 'claims_evidence_api/exceptions/service'
require 'claims_evidence_api/validation'
require 'claims_evidence_api/x_folder_uri'
require 'common/client/base'

module ClaimsEvidenceApi
  # Proxy Service for the ClaimsEvidence API
  #
  # @see https://depo-platform-documentation.scrollhelp.site/developer-docs/endpoint-monitoring
  # @see https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html
  module Service
    # Base service class for API
    class Base < Common::Client::Base
      configuration ClaimsEvidenceApi::Configuration

      include ClaimsEvidenceApi::Exceptions::Service
      include ClaimsEvidenceApi::Validation

      attr_reader :x_folder_uri

      def initialize
        # assigning configuration here so subclass will inherit
        self.class.configuration ClaimsEvidenceApi::Configuration
        super
      end

      # directly assign a folder identifier
      # @see ClaimsEvidenceApi::XFolderUri#validate
      # @param folder_identifier [String] x_folder_uri header value
      def x_folder_uri=(folder_identifier)
        @x_folder_uri = ClaimsEvidenceApi::XFolderUri.validate(folder_identifier)
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
