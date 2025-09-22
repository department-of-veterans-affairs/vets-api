# frozen_string_literal: true

require 'zip'
require 'common/exceptions'
require 'vba_documents/payload_manager'
require 'vba_documents/upload_validator'
require 'vba_documents/pdf_inspector'
require './lib/webhooks/utilities'

module VBADocuments
  module V2
    class UploadsController < ApplicationController
      include VBADocuments::UploadValidations
      include Webhooks::Utilities
      skip_before_action(:authenticate)

      #  rubocop:disable Metrics/MethodLength
      def submit
        upload_model = UploadFile.new
        begin
          upload_model.multipart.attach(io: StringIO.new(request.raw_post), filename: upload_model.guid)
          upload_model.metadata['version'] = 2
          upload_model.save!

          parts = VBADocuments::MultipartParser.parse(StringIO.new(request.raw_post))
          inspector = VBADocuments::PDFInspector.new(pdf: parts)
          upload_model.update(uploaded_pdf: inspector.pdf_data)

          # Validations
          validate_parts(upload_model, parts)
          validate_metadata(parts[META_PART_NAME], upload_model.consumer_id, upload_model.guid,
                            submission_version: upload_model.metadata['version'].to_i)
          validate_documents(parts)

          perfect_metadata(upload_model, parts, Time.zone.now)

          VBADocuments::UploadProcessor.perform_async(upload_model.guid, caller: self.class.name)
        rescue VBADocuments::UploadError => e
          Rails.logger.warn("UploadError download_and_process for guid #{upload_model.guid}.", e)
          upload_model.update(status: 'error', code: e.code, detail: e.detail)
        rescue Seahorse::Client::NetworkingError => e
          upload_model.update(status: 'error', code: 'DOC104', detail: e.message)
        end
        status = upload_model.status.eql?('error') ? 400 : 200

        render json: VBADocuments::V2::UploadSerializer.new(upload_model), status:
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
