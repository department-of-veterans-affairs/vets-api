# frozen_string_literal: true

require 'claims_evidence_api/configuration'
require 'claims_evidence_api/exceptions/service'
require 'claims_evidence_api/monitor'
require 'claims_evidence_api/validation'
require 'claims_evidence_api/folder_identifier'
require 'common/client/base'

module ClaimsEvidenceApi
  module Service
    # Base service class for API
    class Base < Common::Client::Base
      configuration ClaimsEvidenceApi::Configuration

      include ClaimsEvidenceApi::Exceptions::Service
      include ClaimsEvidenceApi::Validation

      attr_reader :folder_identifier

      def initialize
        # assigning configuration here so subclass will inherit
        self.class.configuration ClaimsEvidenceApi::Configuration
        super
      end

      # @see Common::Client::Base#perform
      def perform(method, path, params, headers = nil, options = nil)
        call_location = caller_locations.first # eg. ClaimsEvidenceApi::Service::Files#upload
        response = super(method, path, params, headers, options) # returns Faraday::Env
        monitor.track_api_request(method, path, response.status, response.reason_phrase, call_location:)
        response
      rescue => e
        code = e.respond_to?(:status) ? e.status : 500
        monitor.track_api_request(method, path, code, e.message, call_location:)
        raise e
      end

      # directly assign a folder identifier
      # @see ClaimsEvidenceApi::FolderIdentifier#validate
      # @param folder_identifier [String] x_folder_uri header value
      def folder_identifier=(folder_identifier)
        @folder_identifier = validate_folder_identifier(folder_identifier)
      end

      # set the folder identifier that the file will be associated to
      # @see ClaimsEvidenceApi::FolderIdentifier#generate
      def folder_identifier_set(folder_type, identifier_type, id)
        @folder_identifier = ClaimsEvidenceApi::FolderIdentifier.generate(folder_type, identifier_type, id)
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
