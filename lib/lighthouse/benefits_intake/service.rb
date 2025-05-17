# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_intake/configuration'
require 'lighthouse/benefits_intake/metadata'
require 'pdf_utilities/pdf_validator'

module BenefitsIntake
  ##
  # Proxy Service for the Lighthouse Benefits Intake API
  #
  # Use this to submit claims that cannot be auto-established, via paper submission (electronic PDF submission to CMP).
  # It is the responsibility of any team sending submissions to Lighthouse to monitor those submissions.
  #
  # @see https://depo-platform-documentation.scrollhelp.site/developer-docs/endpoint-monitoring
  # @see https://developer.va.gov/explore/api/benefits-intake/docs
  #
  class Service < Common::Client::Base
    configuration BenefitsIntake::Configuration

    # TODO: process document error similar to service exception
    class InvalidDocumentError < StandardError; end

    STATSD_KEY_PREFIX = 'api.benefits_intake'
    PDF_VALIDATOR_OPTIONS = {
      size_limit_in_bytes: 100_000_000, # 100 MB
      check_page_dimensions: true,
      check_encryption: true,
      width_limit_in_inches: 78,
      height_limit_in_inches: 101
    }.freeze

    attr_reader :location, :uuid

    ##
    # Perform the upload to BenefitsIntake
    # parameters should be run through validation functions first, to prevent downstream processing errors
    #
    # @raise [JSON::ParserError] if metadata is not a valid JSON String
    # @raise [Errno::ENOENT] if document or each attachment are not valid Files
    #
    # @param metadata [JSONString] metadata to be sent with upload, must be valid JSON
    # @param document [String] main document file path
    # @param attachments [Array<String>] attachment file path; optional, default = []
    # @param upload_url [String] override instance upload_url; optional, default = @location
    #
    def perform_upload(metadata:, document:, attachments: [], upload_url: nil)
      # 1) Metadata Validation
      parsed_meta     = JSON.parse(metadata)
      validated_meta  = valid_metadata?(metadata: parsed_meta)
      metadata        = validated_meta.to_json

      # 2) Main document & attachments validation
      document        = valid_document?(document:)
      attachments     = attachments.map { |att| valid_document?(document: att) }

      upload_url, _uuid = request_upload unless upload_url

      meta_tmp = Common::FileHelpers.generate_random_file(metadata)

      params = {}
      params[:metadata] = Faraday::UploadIO.new(meta_tmp, Mime[:json].to_s, 'metadata.json')
      params[:content] = Faraday::UploadIO.new(document, Mime[:pdf].to_s, File.basename(document))
      attachments.each.with_index do |attachment, i|
        params[:"attachment#{i + 1}"] = Faraday::UploadIO.new(attachment, Mime[:pdf].to_s, File.basename(attachment))
      end

      perform :put, upload_url, params, { 'Content-Type' => 'multipart/form-data' }
    ensure
      Common::FileHelpers.delete_file_if_exists(meta_tmp) if meta_tmp
    end

    ##
    # Instantiates a new location and uuid for upload to BenefitsIntake
    #
    # @param [Boolean] refresh
    #
    def request_upload(refresh: false)
      if refresh || !(@location && @uuid)
        uploads = perform :post, 'uploads', {}, {}

        @location = uploads.body.dig('data', 'attributes', 'location')
        @uuid = uploads.body.dig('data', 'id')
      end

      [@location, @uuid]
    end

    ##
    # Get the status for a previous upload
    #
    # @param [String] uuid
    #
    def get_status(uuid:)
      headers = { 'Accept' => Mime[:json].to_s }
      perform :get, "uploads/#{uuid}", {}, headers
    end

    ##
    # Get the status for a set of prior uploads
    #
    # @param [Array<String>] uuids
    #
    def bulk_status(uuids:)
      headers = { 'Content-Type' => Mime[:json].to_s, 'Accept' => Mime[:json].to_s }
      data = { ids: uuids }.to_json
      perform :post, 'uploads/report', data, headers
    end

    ##
    # Download a zip of 'what the server sees' for a previous upload
    #
    # @param [String] uuid
    #
    def download(uuid:)
      headers = { 'Accept' => Mime[:zip].to_s }
      perform :get, "uploads/#{uuid}/download", {}, headers
    end

    ##
    # Validate the metadata satisfies BenefitsIntake specifications.
    # @see BenefitsIntake::Metadata.validate
    #
    # @param [Hash] metadata
    #
    # @return [Hash] validated and corrected metadata
    #
    def valid_metadata?(metadata:)
      BenefitsIntake::Metadata.validate(metadata)
    end

    ##
    # Validate a file satisfies BenefitsIntake specifications.
    # ** File must be a PDF.
    #
    # @raise [InvalidDocumentError] if document is not a valid pdf
    # @see PDF_VALIDATOR_OPTIONS
    #
    # @param [String] document: path to file
    #
    # @returns [String] path to file
    #
    def valid_document?(document:)
      result = PDFUtilities::PDFValidator::Validator.new(document, PDF_VALIDATOR_OPTIONS).validate
      raise InvalidDocumentError, "Invalid Document: #{result.errors}" unless result.valid_pdf?

      doc = File.read(document, mode: 'rb')
      headers = { 'Content-Type': Marcel::MimeType.for(doc) }
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
    #
    # @return [Hash] payload for upload
    #
    def valid_upload?(metadata:, document:, attachments: [])
      {
        metadata: valid_metadata?(metadata:),
        document: valid_document?(document:),
        attachments: attachments.map { |attachment| valid_document?(document: attachment) }
      }
    end

    # end Service
  end

  # end BenefitsIntake
end
