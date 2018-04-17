# frozen_string_literal: true

require_dependency 'vba_documents/multipart_parser'

module VBADocuments
  class UploadProcessor
    include Sidekiq::Worker

    def perform(guid)
      upload = VBADocuments::UploadSubmission.find_by(guid: guid)
      tempfile = download_raw_file(guid)
      parts = VBADocuments::MultipartParser.parse(tempfile.path)
      Rails.logger.info(parts)
      validate_parts(parts)
      metadata = perfect_metadata(parts, upload)
      response = submit(metadata, parts)
      process_response(response, upload)
    end

    private

    def submit(metadata, parts)
      parts['document'].rewind
      body = {
        'metadata' => metadata.to_json,
        'document' => to_faraday_upload(parts['document'], 'document.pdf')
      }
      attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
      attachment_names.each_with_index do |att, i|
        parts[att].rewind
        body["attachment#{i + 1}"] = to_faraday_upload(parts[att], "attachment#{i + 1}.pdf")
      end
      PensionBurial::Service.new.upload(body)
    end

    def to_faraday_upload(file_io, filename)
      Faraday::UploadIO.new(
        file_io,
        Mime[:pdf].to_s,
        filename
      )
    end

    def process_response(response, upload)
      Rails.logger.info(response.status)
      Rails.logger.info(response.body)
      if response.success?
        upload.update(status: 'received')
      else
        upload.update(status: 'error')
        # TODO: store downstream status code/message
      end
    end

    def download_raw_file(guid)
      object = bucket.object(guid)
      tempfile = Tempfile.new(guid)
      object.download_file(tempfile.path)
      tempfile
    end

    def validate_parts(parts); end

    def perfect_metadata(parts, upload)
      metadata = JSON.parse(parts['metadata'])
      metadata['receiveDt'] = upload.updated_at.in_time_zone('US/Central').strftime('%Y-%m-%d %H:%M:%S')
      metadata['uuid'] = upload.guid
      doc_info = get_hash_and_pages(parts['document'])
      metadata['hashV'] = doc_info[:hash]
      metadata['numberPages'] = doc_info[:pages]
      attachment_names = parts.keys.select { |k| k.match(/attachment\d+/) }
      metadata['numberAttachments'] = attachment_names.size
      attachment_names.each_with_index do |att, i|
        att_info = get_hash_and_pages(parts[att])
        metadata["ahash#{i + 1}"] = att_info[:hash]
        metadata["numberPages#{i + 1}"] = att_info[:pages]
      end
      Rails.logger.info(metadata)
      metadata
    end

    def get_hash_and_pages(file_path)
      {
        hash: Digest::SHA256.file(file_path).hexdigest,
        pages: PDF::Reader.new(file_path).pages.size
      }
    end

    def bucket
      @bucket ||= begin
        s3 = Aws::S3::Resource.new(region: Settings.documents.s3.region,
                                   access_key_id: Settings.documents.s3.aws_access_key_id,
                                   secret_access_key: Settings.documents.s3.aws_secret_access_key)
        s3.bucket(Settings.documents.s3.bucket)
      end
    end
  end
end
