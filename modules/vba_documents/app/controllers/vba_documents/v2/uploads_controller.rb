# frozen_string_literal: true

require 'zip'

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'
require_dependency 'vba_documents/payload_manager'
require_dependency 'vba_documents/upload_validator'
require_dependency 'vba_documents/multipart_parser'
load('/srv/vets-api/src/modules/vba_documents/lib/vba_documents/upload_validator.rb')
require 'common/exceptions'

module VBADocuments
  module V2
    class UploadsController < ApplicationController
      include VBADocuments::UploadValidations
      skip_before_action(:authenticate)

      def submit
        upload_model = UploadFile.new
        begin
          upload_model.multipart.attach(io: StringIO.new(request.raw_post), filename: upload_model.guid)
          upload_model.save!
          parts = VBADocuments::MultipartParser.parse(StringIO.new(request.raw_post))
          inspector = VBADocuments::PDFInspector.new(pdf: parts)
          validate_parts(parts)
          validate_metadata(parts[META_PART_NAME])
          update_pdf_metadata(upload_model, inspector)
          perfect_metadata(upload_model, parts, Time.now)
          VBADocuments::UploadProcessor.perform_async(upload_model.guid)
        rescue VBADocuments::UploadError => e
          Rails.logger.warn("UploadError download_and_process for guid #{upload_model.guid}.", e)
          upload_model.update(status: 'error', code: e.code, detail: e.detail)
        end
        status = upload_model.status.eql?('error') ? 400 : 200
        render json: upload_model,
               serializer: VBADocuments::V1::UploadSerializer,
               render_location: false, status: status
      end
    end
  end
end
