# frozen_string_literal: true

require 'zip'

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'
require_dependency 'vba_documents/payload_manager'

module VBADocuments
  module V0
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
               serializer: VBADocuments::UploadSerializer,
               render_location: true
      end

      def show
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:id])

        if submission.nil?
          return render status: :not_found,
                        json: VBADocuments::UploadSubmission.fake_status(params[:id]),
                        serializer: VBADocuments::UploadSerializer,
                        render_location: false
        elsif Settings.vba_documents.enable_status_override && request.headers['Status-Override']
          submission.status = request.headers['Status-Override']
          submission.save
        else
          submission.refresh_status! unless submission.status == 'expired'
        end

        render json: submission,
               serializer: VBADocuments::UploadSerializer,
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

      private

      def verify_settings
        render plain: 'Not found', status: 404 unless Settings.vba_documents.enable_download_endpoint
      end
    end
  end
end
