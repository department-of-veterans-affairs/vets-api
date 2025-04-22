# frozen_string_literal: true

require 'vba_documents/upload_error'
require 'common/file_helpers'
require 'common/virus_scan'

module VBADocuments
  class MultipartParser
    LINE_BREAK = "\r\n"
    BASE64_PREFIX = 'data:multipart/form-data;base64,'

    def self.parse(file_path)
      file_path = decode_base64_file(file_path) if base64_encoded_file?(file_path)

      validate_virus_free(file_path) if Flipper.enabled?(:vba_documents_virus_scan)

      parse_file(file_path)
    end

    def self.parse_file(file_path)
      parts = {}

      File.open(file_path, 'rb') do |input|
        lines = input.each_line(LINE_BREAK).lazy.each_with_index
        separator = consume_first_line(lines)

        loop do
          headers = consume_headers(lines, separator)
          partname = get_partname(headers)
          content_type = get_content_type(headers)
          body, moreparts = consume_body(lines, separator, content_type)
          parts[partname] = body
          break unless moreparts
        end
      end

      parts
    end

    def self.consume_first_line(lines)
      lines.next[0].chomp(LINE_BREAK)
    rescue StopIteration
      Rails.logger.error('Tempfile was found empty')
      raise
    end

    def self.base64_encoded_file?(file_path)
      File.read(file_path).start_with?(BASE64_PREFIX)
    end

    def self.decode_base64_file(original_file_path)
      Rails.logger.info("#{self} starting to decode Base64 submission contents")

      contents = `sed -r 's/data:multipart\\/.{3,},//g' #{original_file_path.shellescape}`
      decoded_data = Base64.decode64(contents)

      Rails.logger.info("#{self} finished decoding Base64 submission contents")

      decoded_file = Tempfile.new('vba_doc_base64_decoded', binmode: true)
      decoded_file.write(decoded_data)
      decoded_file.rewind

      Rails.logger.info("#{self} finished writing Base64-decoded file")

      decoded_file.path
    end

    def self.validate_virus_free(file_path)
      temp_path = Common::FileHelpers.generate_clamav_temp_file(file_path)
      result = Common::VirusScan.scan(temp_path)
      Common::FileHelpers.delete_file_if_exists(temp_path)

      # Common::VirusScan result will return true or false
      unless result # unless safe
        raise VBADocuments::UploadError.new(code: 'DOC101', detail: 'Virus detected in submission')
      end

      true
    end

    def self.get_partname(headers)
      headers.each do |header|
        name, _, value = header.partition(':')
        if name.downcase == 'content-disposition'
          value.split(';').each do |param|
            k, _, v = param.strip.partition('=')
            return v.tr('"', '') if k == 'name'
          end
        end
      end
      raise VBADocuments::UploadError.new(code: 'DOC101',
                                          detail: 'Missing part name parameter in header')
    end

    def self.get_content_type(headers)
      headers.each do |header|
        name, _, value = header.partition(':')
        return value.split(';')[0].strip if name.downcase == 'content-type'
      end
      raise VBADocuments::UploadError.new(code: 'DOC101',
                                          detail: 'Missing content-type header')
    end

    def self.consume_headers(lines, _separator)
      result = []
      loop do
        begin
          line = lines.next[0].chomp(LINE_BREAK)
        rescue StopIteration
          raise VBADocuments::UploadError.new(code: 'DOC101',
                                              detail: 'Unexpected end of payload')
        end
        return result if line == ''

        result << line
      end
    end

    def self.consume_body(lines, separator, content_type)
      case content_type
      when 'application/pdf'
        consume_body_tempfile(lines, separator)
      when 'application/json'
        consume_body_string(lines, separator)
      else
        raise VBADocuments::UploadError.new(code: 'DOC101',
                                            detail: "Unsupported content-type #{content_type}")
      end
    end

    def self.consume_body_string(lines, separator)
      StringIO.open(+'', 'w') do |tf|
        loop do
          begin
            line = lines.next[0]
          rescue StopIteration
            raise VBADocuments::UploadError.new(code: 'DOC101',
                                                detail: 'Unexpected end of payload')
          end
          linechomp = line.chomp(LINE_BREAK)
          case linechomp
          when "#{separator}--"
            return tf.string, false
          when separator
            return tf.string, true
          else
            tf.write(line)
          end
        end
      end
    end

    def self.consume_body_tempfile(lines, separator)
      tf = Tempfile.new('vba_doc', binmode: true)
      loop do
        begin
          line = lines.next[0]
        rescue StopIteration
          raise VBADocuments::UploadError.new(code: 'DOC101', detail: 'Unexpected end of payload')
        end
        linechomp = line.chomp(LINE_BREAK)
        case linechomp
        when "#{separator}--"
          tf.rewind
          return tf, false
        when separator
          tf.rewind
          return tf, true
        else
          tf.write(line)
        end
      end
    end
  end
end
