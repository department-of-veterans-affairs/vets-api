# frozen_string_literal: true

require 'zip'

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'
require_dependency 'vba_documents/payload_manager'

module VBADocuments
  module V1
    class UploadsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :verify_settings, only: [:download]

      def create
        submission = VBADocuments::UploadSubmission.create(
          consumer_name: request.headers['X-Consumer-Username'],
          consumer_id: request.headers['X-Consumer-ID']
        )

        render status: :accepted,
               json: submission,
               serializer: VBADocuments::V1::UploadSerializer,
               render_location: true
      end

      def show
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:id])

        if Settings.vba_documents.enable_status_override && request.headers['Status-Override']
          submission.status = request.headers['Status-Override']
          submission.save
        end

        if submission.nil? || submission.status == 'expired'
          raise Common::Exceptions::RecordNotFound, params[:id]
        elsif submission.status == 'error'
          render json: to_json_api_errors(submission)
        else
          submission.refresh_status!
          render json: submission,
                 serializer: VBADocuments::V1::UploadSerializer,
                 render_location: false
        end
      end

      def download
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:upload_id])

        zip_file_name = VBADocuments::PayloadManager.zip(submission)

        File.open(zip_file_name, 'r') do |f|
          send_data f.read, filename: "#{submission.guid}.zip", type: 'application/zip'
        end

        File.delete(zip_file_name)
      end

      private

      def verify_settings
        render plain: 'Not found', status: 404 unless Settings.vba_documents.enable_download_endpoint
      end

      def to_json_api_errors(submission)
        {
          "errors": [
            {
              "status": '422',
              "details": "#{submission.code} - #{submission.detail}"
            }
          ]
        }
      end
    end
  end
end
