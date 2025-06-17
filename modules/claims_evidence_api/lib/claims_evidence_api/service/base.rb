# frozen_string_literal: true

require 'claims_evidence_api/configuration'
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

      # retrieve the header value
      def x_folder_uri?
        @x_folder_uri
      end

      # The Folder identifier to associate with a request
      # Header Format: folder-type:identifier-type:ID
      # Valid Folder-Types:
      # * VETERAN - Allows: FILENUMBER, SSN, PARTICIPANT_ID, SEARCH, ICN and EDIPI
      # * PERSON - Allows: PARTICIPANT_ID, SEARCH
      # eg. VETERAN:FILENUMBER:987267855
      def x_folder_uri(type, identifier, id)
        # TODO: validate arguments
        @x_folder_uri = "#{type}:#{identifier}:#{id}"
      end
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
