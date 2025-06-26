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

      # The Folder identifier to associate with a request
      # > Header Format: folder-type:identifier-type:ID
      # > Valid Folder-Types:
      # > * VETERAN - Allows: FILENUMBER, SSN, PARTICIPANT_ID, SEARCH, ICN and EDIPI
      # > * PERSON - Allows: PARTICIPANT_ID, SEARCH
      # > eg. VETERAN:FILENUMBER:987267855
      #
      # @param folder_type [String] folder-type
      # @param identifier_type [String] indentifier-type; dependent on folder-type
      # @param id [String] ID
      #
      # @return [String] combined identifer to be used in the request header
      def x_folder_uri_set(folder_type, identifier_type, id)
        @x_folder_uri = ClaimsEvidenceApi::XFolderUri.generate(folder_type, identifier_type, id)
      end
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
