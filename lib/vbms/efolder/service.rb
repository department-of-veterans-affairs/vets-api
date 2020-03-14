# frozen_string_literal: true
module VBMS
  module Efolder
    class Service < Common::Client::Base
      STATSD_KEY_PREFIX = 'api.vbms.efolder.uploads'
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
          raise "Could not process file of type #{file.class.to_s}"
        end
        metadata['content_hash'] = Digest::SHA1.hexdigest(@file.read)
        @filename = SecureRandom.uuid + '-' + @filename
        @metadata = metadata
      end

      def upload_file!
        # uploading to efolder is a two step process. Fetch token and upload.
        token = fetch_upload_token
        upload(token)
        increment_success(:upload, :token)
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

      def client
        @client ||= VBMS::Client.from_env_vars(env_name: Settings.vbms.env)
      end

      def increment_success(*keys)
        keys.each do |key|
          StatsD.increment("#{STATSD_KEY_PREFIX}.#{key}.success")
        end
      end
      
      def increment_fail(*keys)
        keys.each do |key|
          StatsD.increment("#{STATSD_KEY_PREFIX}.#{key}.fail")
        end
      end
    end
  end
end