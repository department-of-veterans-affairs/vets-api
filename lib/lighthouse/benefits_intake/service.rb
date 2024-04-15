# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_intake/configuration'
require 'lighthouse/benefits_intake/metadata'

module BenefitsIntake
  ##
  # Proxy Service for the Lighthouse Claims Intake API Service.
  # We are using it here to submit claims that cannot be auto-established,
  # via paper submission (electronic PDF submissiont to CMP)
  #
  # https://developer.va.gov/explore/api/benefits-intake/docs
  #
  class Service < Common::Client::Base
    configuration BenefitsIntake::Configuration

    # TODO: process document error similar to service exception
    class InvalidDocumentError < StandardError; end

    STATSD_KEY_PREFIX = 'api.benefits_intake'

    attr_reader :location, :uuid

    ##
    # Perform the upload to BenefitsIntake
    # parameters should be run through validation functions first, to prevent downstream processing errors
    #
    # @param [Hash] metadata
    # @param [String] document
    # @param [Array<String>] attachments; optional, default = []
    # @param [String] upload_url; optional, default = @location
    #
    def perform_upload(metadata:, document:, attachments: [], upload_url: nil)
      upload_url, _uuid = request_upload unless upload_url

      meta_tmp = Common::FileHelpers.generate_temp_file(metadata.to_s, "#{STATSD_KEY_PREFIX}.#{@uuid}.metadata.json")

      params = {}
      params[:metadata] = Faraday::UploadIO.new(meta_tmp, Mime[:json].to_s, 'metadata.json')
      params[:content] = Faraday::UploadIO.new(document, Mime[:pdf].to_s, File.basename(document))
      attachments.each.with_index do |attachment, i|
        params[:"attachment#{i + 1}"] = Faraday::UploadIO.new(attachment, Mime[:pdf].to_s, File.basename(attachment))
      end

      perform :put, upload_url, params, { 'Content-Type' => 'multipart/form-data' }
    end

    ##
    # Instantiates a new location and uuid for upload to BenefitsIntake
    #
    # @param [Boolean] refresh
    #
    def request_upload(refresh: false)
      if !@uploads || refresh
        @uploads = perform :post, 'uploads', {}, {}

        @location = @uploads.body.dig('data', 'attributes', 'location')
        @uuid = @uploads.body.dig('data', 'id')
      end

      [@location, @uuid]
    end

    ##
    # Get the status for a previous upload
    #
    # @param [String] uuid
    #
    def get_status(uuid:)
      headers = { 'accept' => Mime[:json].to_s }
      perform :get, "uploads/#{uuid}", {}, headers
    end

    ##
    # Get the status for a set of prior uploads
    #
    # @param [Array<String>] uuids
    #
    def bulk_status(uuids:)
      headers = { 'Content-Type' => Mime[:json].to_s, 'accept' => Mime[:json].to_s }
      data = { uuids: }.to_json
      perform :post, 'uploads/report', data, headers
    end

    ##
    # Download a zip of 'what the server sees' for a previous upload
    #
    # @param [String] uuid
    #
    def download(uuid:)
      headers = { 'accept' => Mime[:zip].to_s }
      perform :get, "uploads/#{uuid}/download", {}, headers
    end

    ##
    # Validate the metadata satisfies BenefitsIntake specifications.
    # @see BenefitsIntake::Metadata.validate
    #
    # @param [Hash] metadata
    #
    # @returns [Hash] validated and corrected metadata
    #
    def valid_metadata?(metadata:)
      BenefitsIntake::Metadata.validate(metadata)
    end

    ##
    # Validate a file satisfies BenefitsIntake specifications. File must be a PDF.
    #
    # @param [String] document
    # @param [Hash] headers; optional, default nil
    #
    def valid_document?(document:, headers: nil)
      doc = File.read(document, mode: 'rb')

      doc_mime = Marcel::MimeType.for(doc)
      raise TypeError, "Invalid Document MimeType: #{doc_mime}" if doc_mime != Mime[:pdf].to_s

      headers = (headers || {}).merge({ 'Content-Type': doc_mime })
      response = perform :post, 'uploads/validate_document', doc, headers

      raise InvalidDocumentError, "Invalid Document: #{response}" unless response.success?

      document
    end

    ##
    # Validate the upload meets BenefitsIntake specifications.
    #
    # @param [Hash] metadata
    # @param [String] document
    # @param [Array<String>] attachments; optional, default []
    # @param [Hash] headers; optional, default nil
    #
    # @return [Hash] payload for upload
    #
    def valid_upload?(metadata:, document:, attachments: [], headers: nil)
      {
        metadata: valid_metadata?(metadata:),
        document: valid_document?(document:, headers:),
        attachments: attachments.map { |attachment| valid_document?(document: attachment, headers:) }
      }
    end

    # end Service
  end

  # end BenefitsIntake
end
