# frozen_string_literal: true

require 'claims_evidence_api/configuration'
require 'claims_evidence_api/exceptions/service'
require 'claims_evidence_api/monitor'
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

      # @see Common::Client::Base#perform
      def perform(method, path, params, headers = nil, options = nil)
        call_location = caller_locations.first # eg. ClaimsEvidenceApi::Service::Files#upload
        response = super(method, path, params, headers, options)
        monitor.track_api_request(method, path, response.status, response.reason_phrase, call_location:)
        response
      rescue => e
        code = e.respond_to?(:status) ? e.status : 500
        monitor.track_api_request(method, path, code, e.message, call_location:)
        raise e
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

      private

      # create the monitor to be used for _this_ instance
      # @see ClaimsEvidenceApi::Monitor::Service
      def monitor
        @monitor ||= ClaimsEvidenceApi::Monitor::Service.new
      end
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
