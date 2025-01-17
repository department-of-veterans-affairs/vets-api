# frozen_string_literal: true

require 'zip'
require 'vba_documents/payload_manager'
require 'common/exceptions'

module VBADocuments
  module V1
    class UploadsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :verify_download_enabled, only: [:download]
      before_action :verify_validate_enabled, only: [:validate_document]

      def show
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:id])

        if submission.nil?
          raise Common::Exceptions::RecordNotFound, params[:id]
        elsif Settings.vba_documents.enable_status_override && request.headers['Status-Override']
          submission.status = request.headers['Status-Override']
          submission.save
        else
          begin
            submission.refresh_status! unless submission.status == 'expired'
          rescue Common::Exceptions::GatewayTimeout, Common::Exceptions::BadGateway => e
            # Rescue and log (but don't raise exception), so that last cached status is returned
            message = "Status refresh failed for submission on #{controller_name}##{action_name}, GUID: #{params[:id]}"
            Rails.logger.warn(message, e)
          end
        end

        options = { params: { render_location: false } }
        render json: VBADocuments::V1::UploadSerializer.new(submission, options)
      end

      def create
        submission = VBADocuments::UploadSubmission.create(
          consumer_name: request.headers['X-Consumer-Username'],
          consumer_id: request.headers['X-Consumer-ID']
        )
        submission.metadata['version'] = 1
        submission.save!
        options = { params: { render_location: true } }
        render json: VBADocuments::V1::UploadSerializer.new(submission, options), status: :accepted
      end

      def download
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:upload_id])
        raise Common::Exceptions::RecordNotFound, params[:upload_id] if submission.nil?

        zip_file_name = VBADocuments::PayloadManager.zip(submission)

        File.open(zip_file_name, 'r') do |f|
          send_data f.read, filename: "#{submission.guid}.zip", type: 'application/zip'
        end

        File.delete(zip_file_name)
      end

      def validate_document
        validator = DocumentRequestValidator.new(request)
        result = validator.validate

        if result[:errors].present?
          render json: result, status: :unprocessable_entity
        else
          render json: result
        end
      end

      private

      def verify_download_enabled
        render_not_found unless Settings.vba_documents.enable_download_endpoint
      end

      def verify_validate_enabled
        render_not_found unless Settings.vba_documents.enable_validate_document_endpoint
      end

      def render_not_found
        render plain: 'Not found', status: :not_found
      end
    end
  end
end
