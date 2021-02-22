# frozen_string_literal: true

require 'vba_documents/upload_error'

module VBADocuments
  class MultipartParser
    LINE_BREAK = "\r\n"
    CARRIAGE_RETURN = "\r"

    def self.parse(infile)
      if base64_encoded(infile)
        create_file_from_base64(infile)
      else
        parse_file(infile)
      end
    end

    # rubocop:disable Metrics/MethodLength
    def self.parse_file(infile)
      parts = {}
      begin
        input = if infile.is_a? String
                  File.open(infile, 'rb')
                else
                  infile
                end
        validate_size(input)
        lines = input.each_line(LINE_BREAK).lazy.each_with_index
        separator = lines.next[0].chomp(LINE_BREAK)
        loop do
          headers = consume_headers(lines, separator)
          partname = get_partname(headers)
          content_type = get_content_type(headers)
          body, moreparts = consume_body(lines, separator, content_type)
          parts[partname] = body
          break unless moreparts
        end
      ensure
        input.close
      end
      parts
    end
    # rubocop:enable Metrics/MethodLength

    def self.base64_encoded(infile)
      if infile.is_a? StringIO
        content = infile.read
        infile.rewind
      else
        content = File.read(infile)
      end
      content.start_with?('data:multipart/form-data;base64,')
    end

    def self.create_file_from_base64(infile)
      FileUtils.mkdir_p '/tmp/vets-api'
      if infile.is_a? String
        contents = `sed -r 's/data:multipart\\/.{3,},//g' #{infile}`
      else
        # We are a stringio and are in memory.
        content = infile.read
        infile.rewind
        contents = content.sub %r{data:((multipart)/.{3,}),}, ''
      end
      decoded_data = Base64.decode64(contents)
      filename = "temp_upload_#{Time.zone.now.to_i}"

      File.open("/tmp/vets-api/#{filename}", 'wb') do |f|
        f.write(decoded_data)
      end
      parse(File.open("/tmp/vets-api/#{filename}"))
    end

    def self.validate_size(infile)
      unless infile.size.positive?
        raise VBADocuments::UploadError.new(code: 'DOC107',
                                            detail: VBADocuments::UploadError::DOC107)
      end
    end

    def self.get_partname(headers)
      headers.each do |header|
        name, _, value = header.partition(':')
        if name == 'Content-Disposition'
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
        return value.split(';')[0].strip if name == 'Content-Type'
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
      if content_type == 'application/pdf'
        consume_body_tempfile(lines, separator)
      elsif content_type == 'application/json'
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
          if (linechomp == "#{separator}--") || (linechomp == "#{separator}--#{CARRIAGE_RETURN}")
            return tf.string, false
          elsif linechomp == separator
            return tf.string, true
          else
            tf.write(line)
          end
        end
      end
    end

    def self.consume_body_tempfile(lines, separator)
      tf = Tempfile.new('vba_doc')
      tf.binmode
      loop do
        begin
          line = lines.next[0]
        rescue StopIteration
          raise VBADocuments::UploadError.new(code: 'DOC101',
                                              detail: 'Unexpected end of payload')
        end
        linechomp = line.chomp(LINE_BREAK)
        if (linechomp == "#{separator}--") || (linechomp == "#{separator}--#{CARRIAGE_RETURN}")
          tf.rewind
          return tf, false
        elsif linechomp == separator
          tf.rewind
          return tf, true
        else
          tf.write(line)
        end
      end
    end
  end
end
