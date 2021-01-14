# frozen_string_literal: true

require 'zip'

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'
require_dependency 'vba_documents/payload_manager'
require 'common/exceptions'

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

      def upload
        model = UploadFile.new
        #content = params[:content]
        at1 = params[:attachment1]
        #at2 = params[:attachment2]
        raise "give me a file numbnuts!" if at1.nil?
        content_name = model.guid + '_' + 'content'
        at1_name = model.guid + '_' + 'attachment1'
        at2_name = model.guid + '_' + 'attachment2'
        metadata = JSON.parse(params['metadata']).merge({guid: model.guid, content: content_name, attachments: [at1_name, at2_name]})
        model.metadata = metadata
        # model.files.attach(io: content.tempfile, filename: content_name) #todo change filename to guid
        # model.files.attach(io: at1.tempfile, filename: at1_name) #todo change filename to guid
        # model.files.attach(io: at2.tempfile, filename: at2_name) #todo change filename to guid
        model.files.attach(io: StringIO.new(request.raw_post), filename: model.guid) #todo change filename to guid
        model.save!
        # model.parse_and_upload!
        VBADocuments::UploadProcessor.new.perform(model.guid)
        params[:id] = model.guid
        # @upload = VBADocuments::UploadSubmission.find_by(guid: guid)
        show
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
        render plain: 'Not found', status: :not_found unless Settings.vba_documents.enable_download_endpoint
      end
    end
  end
end
