# frozen_string_literal: true
module VBMS
  module Efolder
    class Service < Common::Client::Base
      STATSD_KEY_PREFIX = 'api.vbms_efolder'
      include Common::Client::Monitoring
      configuration VBMS::Efolder::Configuration
      
      def initialize(file, metadata)
        case file.class.to_s
        when 'ClaimDocumentation::Uploader::UploadedFile'
          @filename = file.original_filename
          @file = file.to_io
        when 'File'
          @filename = File.basename(file)
          @file = file
        else
          raise
        end
        @filename = SecureRandom.uuid + '-' + @filename
        @metadata = metadata
      end

      def upload_file!
        # uploading to efolder is a two step process. Fetch token and upload.
        token = fetch_upload_token
        upload(token)
      end

      private

      def fetch_upload_token
        content_hash = Digest::SHA1.hexdigest(@file.read)
        vbms_request = VBMS::Requests::InitializeUpload.new(
          content_hash: content_hash,
          filename: @filename,
          file_number: @metadata['file_number'],
          va_receive_date: @metadata['receive_date'],
          doc_type: @metadata['doc_type'],
          source: @metadata['source'],
          subject: @metadata['source'] + '_' + @metadata['doc_type'], # TODO
          new_mail: true # TODO
        )
        # token = client.send_request(vbms_request)
        token = SecureRandom.uuid # stub for dev
        token
      rescue
        # TODO: handle service outages and invalid files
        raise
      end

      def upload(token)
        binding.pry
        upload_request = VBMS::Requests::UploadDocument.new(
          upload_token: token,
          filepath: @file.path
        )
        client.send_request(upload_request)
      rescue
        raise
      end

      def client
        @client ||= VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
      end
    end
  end
end