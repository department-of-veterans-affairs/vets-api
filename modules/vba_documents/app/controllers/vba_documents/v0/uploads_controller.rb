# frozen_string_literal: true

require 'zip'

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'
require_dependency 'vba_documents/object_store'
require_dependency 'vba_documents/multipart_parser'

module VBADocuments
  module V0
    class UploadsController < ApplicationController
      skip_before_action(:authenticate)

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

        if Settings.vba_documents.enable_status_override && request.headers['Status-Override']
          submission.status = request.headers['Status-Override']
          submission.save
        end

        if submission.nil? || submission.status == 'expired'
          render status: :not_found,
                 json: VBADocuments::UploadSubmission.fake_status(params[:id]),
                 serializer: VBADocuments::UploadSerializer,
                 render_location: false
        else
          submission.refresh_status!
          render json: submission,
                 serializer: VBADocuments::UploadSerializer,
                 render_location: false
        end
      end

      def download
        raise ActionController::RoutingError, 'Not Found' unless Settings.vba_documents.enable_download_endpoint

        submission = VBADocuments::UploadSubmission.find_by(guid: params[:upload_id])
        raw_file = download_raw_file(submission.guid)
        parsed = VBADocuments::MultipartParser.parse(raw_file.path)
        files = [
          { name: 'content.pdf', path: parsed['content'].path },
          { name: 'metadata.json', path: write_json(submission.guid, parsed).path }
        ] + attachments(parsed)
        zip_file_name = "/tmp/#{submission.guid}.zip"

        Zip::File.open(zip_file_name, Zip::File::CREATE) do |zipfile|
          files.each do |file|
            zipfile.add(file[:name], file[:path])
          end
        end

        File.open(zip_file_name, 'r') do |f|
          send_data f.read, filename: "#{submission.guid}.zip", type: 'application/zip'
        end

        File.delete(zip_file_name)
      end

      private

      def download_raw_file(guid)
        store = VBADocuments::ObjectStore.new
        tempfile = Tempfile.new(guid)
        version = store.first_version(guid)
        store.download(version, tempfile.path)
        tempfile
      end

      def attachments(parsed)
        attachment_keys = parsed.keys.select { |key| key.include? 'attachment' }
        parsed.slice(*attachment_keys).map { |k, v| { name: "#{k}.pdf", path: v.path } }
      end

      def write_json(guid, parsed)
        tempfile = Tempfile.new("#{guid}_metadata.json")
        tempfile.write(parsed['metadata'])
        tempfile.close
        tempfile
      end
    end
  end
end
