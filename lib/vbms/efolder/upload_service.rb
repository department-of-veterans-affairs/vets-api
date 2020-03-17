# frozen_string_literal: true

module VBMS
  module Efolder
    class UploadService < VBMS::Efolder::Service
      def initialize(file, metadata)
        case file.class.to_s
        when 'ClaimDocumentation::Uploader::UploadedFile'
          # persistant attachment (shrine)
          @filename = file.original_filename
          @file = file.to_io
        when 'File'
          @filename = File.basename(file)
          @file = file
        else
          raise "Could not process file of type #{file.class}"
        end
        metadata['content_hash'] = Digest::SHA1.hexdigest(@file.read)
        @filename = SecureRandom.uuid + '-' + @filename
        @metadata = metadata
      end

      def upload_file!
        # uploading to efolder is a two call process: fetch_token and upload
        token = fetch_upload_token
        upload(token)
        increment_success(:upload, :token) # statsd
      rescue
        increment_fail(:token) unless token
        increment_fail(:upload)
      end

      private

      def fetch_upload_token
        request = initialize_upload
        client.send_request(request) # returns a token
      end

      def initialize_upload
        VBMS::Requests::InitializeUpload.new(
          content_hash: @metadata['content_hash'],
          filename: @filename,
          file_number: @metadata['file_number'],
          va_receive_date: @metadata['receive_date'],
          doc_type: @metadata['doc_type'],
          source: @metadata['source'],
          subject: @metadata['source'] + '_' + @metadata['doc_type'], # TODO?
          new_mail: @metadata['new_mail'] || true # TODO?
        )
      end

      def upload(token)
        upload_request = VBMS::Requests::UploadDocument.new(
          upload_token: token,
          filepath: @file.path
        )
        client.send_request(upload_request)
      end
    end
  end
end
