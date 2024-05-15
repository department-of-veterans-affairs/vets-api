# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'common/exceptions/forbidden'
require 'common/exceptions/schema_validation_errors'
require 'benefits_intake_service/configuration'
require 'benefits_intake_service/utilities/convert_to_pdf'

module BenefitsIntakeService
  ##
  # Proxy Service for the Lighthouse Claims Intake API Service.
  # We are using it here to submit claims that cannot be auto-established,
  # via paper submission (electronic PDF submission to CMP)
  #
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration BenefitsIntakeService::Configuration

    attr_reader :uuid, :location

    REQUIRED_CREATE_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze

    # Validate a file satisfies Benefits Intake specifications. File must be a PDF.
    # @param [String] doc_path
    def validate_document(doc_path:)
      # TODO: allow headers: to be passed to function if/when other file types are allowed
      headers = { 'Content-Type': 'application/pdf' }
      request_body = File.read(doc_path, mode: 'rb')
      perform :post, 'uploads/validate_document', request_body, headers
    end

    # TODO: Remove param and clean up Form526BackupSubmissionProcess::Processor to use instance vars
    def initialize(with_upload_location: false)
      super()
      if with_upload_location
        upload_return = get_location_and_uuid
        @uuid = upload_return[:uuid]
        @location = upload_return[:location]
      end
    end

    def upload_form(main_document:, attachments:, form_metadata:)
      raise 'Ran Method without Instance Variables' if @location.blank?

      metadata = generate_metadata(form_metadata)
      upload_doc(
        upload_url: @location,
        file: main_document,
        metadata: metadata.to_json,
        attachments:
      )
    end

    def get_upload_location
      headers = {}
      request_body = {}
      perform :post, 'uploads', request_body, headers
    end

    def get_bulk_status_of_uploads(ids)
      body = { ids: }.to_json
      response = perform(
        :post,
        'uploads/report',
        body,
        { 'Content-Type' => 'application/json', 'accept' => 'application/json' }
      )

      raise response.body unless response.success?

      response
    end

    def get_file_path_from_objs(file)
      case file
      when EVSS::DisabilityCompensationForm::Form8940Document
        file.pdf_path
      when CarrierWave::SanitizedFile
        file.file
      when Hash
        get_file_path_from_objs(file[:file])
      else
        file
      end
    end

    def generate_metadata(metadata)
      {
        veteranFirstName: metadata[:veteran_first_name],
        veteranLastName: metadata[:veteran_last_name],
        fileNumber: metadata[:file_number],
        zipCode: metadata[:zip],
        source: 'va.gov backup submission',
        docType: metadata[:doc_type],
        businessLine: 'CMP',
        claimDate: metadata[:claim_date]
      }
    end

    def generate_tmp_metadata_file(metadata)
      Common::FileHelpers.generate_temp_file(metadata.to_s, "#{SecureRandom.hex}.benefits_intake.metadata.json")
    end

    # Instantiates a new location and uuid via lighthouse
    def get_location_and_uuid
      upload_return = get_upload_location
      {
        uuid: upload_return.body.dig('data', 'id'),
        location: upload_return.body.dig('data', 'attributes', 'location')
      }
    end
    # Combines instantiating a new location/uuid and returning the important bits

    def get_upload_docs(file_with_full_path:, metadata:, attachments: [])
      json_tmpfile = generate_tmp_metadata_file(metadata)
      file_name = File.basename(file_with_full_path)
      params = { metadata: Faraday::UploadIO.new(json_tmpfile, Mime[:json].to_s, 'metadata.json'),
                 content: Faraday::UploadIO.new(file_with_full_path, Mime[:pdf].to_s, file_name) }
      attachments.each.with_index do |attachment, i|
        file_path = get_file_path_from_objs(attachment[:file])
        file_name = attachment[:file_name] || attachment['name']
        params[:"attachment#{i + 1}"] = Faraday::UploadIO.new(file_path, Mime[:pdf].to_s, file_name)
      end
      [params, json_tmpfile]
    end

    def upload_doc(upload_url:, file:, metadata:, attachments: [])
      file_with_full_path = get_file_path_from_objs(file)
      params, _json_tmpfile = get_upload_docs(file_with_full_path:, metadata:,
                                              attachments:)
      response = perform :put, upload_url, params, { 'Content-Type' => 'multipart/form-data' }

      raise response.body unless response.success?

      upload_deletion_logic(file_with_full_path:, attachments:)

      response
    end

    def upload_deletion_logic(file_with_full_path:, attachments:)
      if Rails.env.production?
        Common::FileHelpers.delete_file_if_exists(file_with_full_path) unless permanent_file?(file_with_full_path)
        attachments.each do |evidence_file|
          to_del = get_file_path_from_objs(evidence_file)
          # dont delete the instructions pdf we keep on the fs and send along for bdd claims
          Common::FileHelpers.delete_file_if_exists(to_del) unless permanent_file?(to_del)
        end
      else
        Rails.logger.info("Would have deleted file #{file_with_full_path} if in production env.")
        attachments.each do |evidence_file|
          to_del = get_file_path_from_objs(evidence_file)
          Rails.logger.info("Would have deleted file #{to_del} if in production env.") unless permanent_file?(to_del)
        end
      end
    end

    # Overload in other services to define files not meant to be deleted
    def permanent_file?(_file)
      false
    end
  end
end
