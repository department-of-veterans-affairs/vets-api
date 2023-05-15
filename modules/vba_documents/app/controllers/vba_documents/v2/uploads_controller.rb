# frozen_string_literal: true

require 'zip'
require 'common/exceptions'
require 'vba_documents/payload_manager'
require 'vba_documents/upload_validator'
require './lib/webhooks/utilities'

module VBADocuments
  module V2
    class UploadsController < ApplicationController
      include VBADocuments::UploadValidations
      include Webhooks::Utilities
      skip_before_action(:authenticate)
      before_action :verify_settings, only: [:download]

      #  rubocop:disable Metrics/MethodLength
      def create
        submission = nil
        subscriptions = nil
        VBADocuments::UploadSubmission.transaction do
          submission = VBADocuments::UploadSubmission.create(
            consumer_name: request.headers['X-Consumer-Username'],
            consumer_id: request.headers['X-Consumer-ID']
          )
          observers = params[:observers]
          if observers.respond_to? :read
            subscriptions = validate_subscription(JSON.parse(observers.read))
          elsif observers
            subscriptions = validate_subscription(JSON.parse(observers))
          end

          submission.metadata['version'] = 2
          submission.save!
          if subscriptions
            Webhooks::Utilities.register_webhook(
              submission.consumer_id, submission.consumer_name, subscriptions, submission.guid
            )
          end
        end
        render status: :accepted,
               json: submission,
               serializer: VBADocuments::V2::UploadSerializer,
               render_location: true
      rescue JSON::ParserError => e
        raise Common::Exceptions::SchemaValidationErrors, ["invalid JSON. #{e.message}"] if e.is_a? JSON::ParserError
      end
      # rubocop:enable Metrics/MethodLength

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

        render json: submission,
               serializer: VBADocuments::V2::UploadSerializer,
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

      # rubocop:disable Metrics/MethodLength
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
          validate_metadata(parts[META_PART_NAME], submission_version: upload_model.metadata['version'].to_i)
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
        render json: upload_model, serializer: VBADocuments::V2::UploadSerializer, status:
      end
      # rubocop:enable Metrics/MethodLength

      private

      def verify_settings
        render plain: 'Not found', status: :not_found unless Settings.vba_documents.enable_download_endpoint
      end
    end
  end
end
