# frozen_string_literal: true

# TODO: capture end of file in case of missing termating separator
# TODO add support for base64 encoding
module VBADocuments
  class MultipartParser
    LINE_BREAK = "\r\n"

    def self.parse(infile)
      File.open(infile, 'rb') do |input|
        lines = input.each_line(LINE_BREAK).lazy.each_with_index

        parts = {}
        separator = lines.next[0].chomp(LINE_BREAK)

        loop do
          headers = consume_headers(lines, separator)
          partname = get_partname(headers)
          content_type = get_content_type(headers)
          body, moreparts = consume_body(lines, separator, content_type)
          parts[partname] = body
          break unless moreparts
        end
        parts
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
      nil
    end

    def self.get_content_type(headers)
      headers.each do |header|
        name, _, value = header.partition(':')
        return value.split(';')[0].strip if name == 'Content-Type'
      end
      nil
    end

    def self.consume_headers(lines, _separator)
      result = []
      loop do
        line = lines.next[0].chomp(LINE_BREAK)
        return result if line == ''
        result << line
      end
    end

    def self.consume_body(lines, separator, content_type)
      # TODO: remove text/plain as allowed option
      if ['application/pdf', 'text/plain'].include?(content_type)
        consume_body_tempfile(lines, separator)
      elsif content_type == 'application/json'
        consume_body_string(lines, separator)
      else
        raise "Unsupported content type #{content_type}"
      end
    end

    def self.consume_body_string(lines, separator)
      StringIO.open(+'', 'w') do |tf|
        loop do
          line = lines.next[0]
          linechomp = line.chomp(LINE_BREAK)
          if linechomp == "#{separator}--"
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
        line = lines.next[0]
        linechomp = line.chomp(LINE_BREAK)
        if linechomp == "#{separator}--"
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
