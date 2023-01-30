# frozen_string_literal: true

module VBADocuments
  class UploadIntegrityChecker
    include SentryLogging

    BASE64_PREFIX = 'data:multipart/form-data;base64,'
    LINE_BREAK = "\r\n"

    def initialize(upload_submission, parts)
      @upload_submission = upload_submission
      @boundaries = parts['boundaries']
      @headers = parts['headers']
      @contents = parts['contents']
      @multipart_file = nil
      @multipart_base64_file = nil
    end

    def check_integrity
      Rails.logger.info("#{self.class} starting, guid: #{@upload_submission.guid}")

      begin
        write_multipart_file
        checksum = generate_checksum
        save_checksum(checksum)

        Rails.logger.info("#{self.class} complete, guid: #{@upload_submission.guid}")
      rescue => e
        warning_message = "#{self.class} failed for upload"
        Rails.logger.warn("#{warning_message}, guid: #{@upload_submission.guid}", e.message)
        log_message_to_sentry("#{warning_message}: #{e.message}", :warning)
      ensure
        close_multipart_files
      end
    end

    private

    def write_multipart_file
      @multipart_file = Tempfile.new('vba_doc_multipart', binmode: true)
      write_metadata
      write_content_file
      write_attachments
      write_closing_boundary
      @multipart_file.rewind

      if @upload_submission.base64_encoded?
        encode_file_as_base64
        @multipart_base64_file.rewind
      end
    end

    def write_metadata
      @multipart_file.write(@boundaries['multipart_boundary'] + LINE_BREAK)
      @multipart_file.write(@headers['metadata'] + LINE_BREAK + LINE_BREAK)
      @multipart_file.write(@contents['metadata'])
    end

    def write_content_file
      @multipart_file.write(@boundaries['multipart_boundary'] + LINE_BREAK)
      @multipart_file.write(@headers['content'] + LINE_BREAK + LINE_BREAK)
      @multipart_file.write(@contents['content'].read)
    end

    def write_attachments
      attachment_names = @contents.keys.select { |k| k.match(/attachment\d+/) }
      attachment_names.each do |attach|
        @multipart_file.write(@boundaries['multipart_boundary'] + LINE_BREAK)
        @multipart_file.write(@headers[attach] + LINE_BREAK + LINE_BREAK)
        @multipart_file.write(@contents[attach].read)
      end
    end

    def write_closing_boundary
      @multipart_file.write(@boundaries['closing_boundary'])
    end

    def encode_file_as_base64
      @multipart_base64_file = Tempfile.new('vba_doc_multipart_encoded', binmode: true)
      @multipart_base64_file.write(BASE64_PREFIX)
      @multipart_base64_file.write(Base64.encode64(@multipart_file.read))
    end

    def generate_checksum
      Digest::SHA256.file(@multipart_base64_file || @multipart_file).hexdigest
    end

    def save_checksum(checksum)
      checksum_metadata = @upload_submission.metadata.merge(
        {
          'recalculated_checksum' => checksum,
          'checksums_match' => checksums_match?(checksum)
        }
      )
      @upload_submission.update(metadata: checksum_metadata)

      raise "Checksums don't match!" unless checksums_match?(checksum)
    end

    def checksums_match?(checksum)
      checksum == @upload_submission.metadata['original_checksum']
    end

    def close_multipart_files
      @multipart_file&.close
      @multipart_file&.unlink

      @multipart_base64_file&.close
      @multipart_base64_file&.unlink
    end
  end
end
