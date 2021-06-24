# frozen_string_literal: true

require 'zip'

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'
require_dependency 'vba_documents/payload_manager'
require_dependency 'vba_documents/upload_validator'
require_dependency 'vba_documents/location_validator'
require_dependency 'vba_documents/multipart_parser'
require 'common/exceptions'

module VBADocuments
  module V2
    class UploadsController < ApplicationController
      include VBADocuments::UploadValidations
      include VBADocuments::LoacationValidations
      skip_before_action(:authenticate)
      before_action :verify_settings, only: [:download]

      def create
        load('./modules/vba_documents/lib/vba_documents/location_validator.rb') #allows changes (remove) todo
        submission = nil
        VBADocuments::UploadSubmission.transaction do
          subscriptions = validate_subscription(params[:subscriptions]) if params[:subscriptions]
          submission = VBADocuments::UploadSubmission.create(
              consumer_name: request.headers['X-Consumer-Username'],
              consumer_id: request.headers['X-Consumer-ID']
          )
          # greg_model.create_from_subscriptions(subscriptions, guid)
        end
        render status: :accepted,
               json: submission,
               serializer: VBADocuments::V1::UploadSerializer, # todo v2 validator
               render_location: true
      rescue => ex
        # todo handle exception convert 500 error to 400 return appropriate json (returned from validator above)
        raise ex
      end

      def show
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:id])

        if submission.nil?
          raise Common::Exceptions::RecordNotFound, params[:id]
        elsif Settings.vba_documents.enable_status_override && request.headers['Status-Override']
          submission.status = request.headers['Status-Override']
          submission.save
        else
          submission.refresh_status! unless submission.status == 'expired'
        end

        render json: submission,
               serializer: VBADocuments::V1::UploadSerializer,
               render_location: false
      end

      def download
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:upload_id])

        zip_file_name = VBADocuments::PayloadManager.zip(submission)

        File.open(zip_file_name, 'r') do |f|
          send_data f.read, filename: "#{submission.guid}.zip", type: 'application/zip'
        end

        File.delete(zip_file_name)
      end

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
          perfect_metadata(upload_model, parts, Time.zone.now)
          VBADocuments::UploadProcessor.perform_async(upload_model.guid, caller: self.class.name)
        rescue VBADocuments::UploadError => e
          Rails.logger.warn("UploadError download_and_process for guid #{upload_model.guid}.", e)
          upload_model.update(status: 'error', code: e.code, detail: e.detail)
        rescue Seahorse::Client::NetworkingError => e
          upload_model.update(status: 'error', code: 'DOC104', detail: e.message)
        end
        status = upload_model.status.eql?('error') ? 400 : 200
        render json: upload_model,
               serializer: VBADocuments::V2::UploadSerializer, status: status
      end

      private

      def verify_settings
        render plain: 'Not found', status: :not_found unless Settings.vba_documents.enable_download_endpoint
      end

    end
  end
end
