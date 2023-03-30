# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'common/exceptions/forbidden'
require 'common/exceptions/schema_validation_errors'
require 'form526_backup_submission/configuration'

module Form526BackupSubmission
  ##
  # Proxy Service for the Lighthouse Claims Intake API Service.
  # We are using it here to submit claims that cannot be auto-established,
  # via paper submission (electronic PDF submissiont to CMP)
  #
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration Form526BackupSubmission::Configuration

    REQUIRED_CREATE_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze

    def get_upload_location
      headers = {}
      request_body = {}
      perform :post, 'uploads', request_body, headers
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

    def generate_tmp_metadata(metadata)
      Common::FileHelpers.generate_temp_file(metadata.to_s, "#{SecureRandom.hex}.Form526Backup.metadata.json")
    end

    def bdd_file?(file)
      file.include?('bdd_instructions.pdf')
    end

    def upload_deletion_logic(file_with_full_path:, attachments:)
      if Rails.env.production?
        Common::FileHelpers.delete_file_if_exists(file_with_full_path) unless bdd_file?(file_with_full_path)
        attachments.each do |evidence_file|
          to_del = get_file_path_from_objs(evidence_file)
          # dont delete the instructions pdf we keep on the fs and send along for bdd claims
          Common::FileHelpers.delete_file_if_exists(to_del) unless bdd_file?(to_del)
        end
      else
        Rails.logger.info("Would have deleted file #{file_with_full_path} if in production env.")
        attachments.each do |evidence_file|
          to_del = get_file_path_from_objs(evidence_file)
          Rails.logger.info("Would have deleted file #{to_del} if in production env.") unless bdd_file?(to_del)
        end
      end
    end

    def get_upload_docs(file_with_full_path:, metadata:, attachments: [])
      json_tmpfile = generate_tmp_metadata(metadata)
      file_name = File.basename(file_with_full_path)
      params = { metadata: Faraday::UploadIO.new(json_tmpfile, Mime[:json].to_s, 'metadata.json'),
                 content: Faraday::UploadIO.new(file_with_full_path, Mime[:pdf].to_s, file_name) }
      attachments.each.with_index do |attachment, i|
        file_path = get_file_path_from_objs(attachment[:file])
        file_name = attachment[:file_name] || attachment['name']
        params["attachment#{i + 1}".to_sym] = Faraday::UploadIO.new(file_path, Mime[:pdf].to_s, file_name)
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
  end
end
