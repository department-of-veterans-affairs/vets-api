# frozen_string_literal: true

module PdfInfo
  class MetadataReadError < RuntimeError
    def initialize(status, stdout)
      super "pdfinfo exited with status #{status} and message #{stdout}"
    end
  end

  class Metadata
    def self.read(file_or_path)
      if file_or_path.is_a? String
        new(file_or_path)
      else
        new(file_or_path.path)
      end
    end

    def initialize(path)
      @stdout = []
      Open3.popen2e(Settings.binaries.pdfinfo, path) do |_stdin, stdout, wait|
        stdout.each_line do |line|
          @stdout.push(force_utf8_encoding(line))
        end
        @exit_status = wait.value
      end
      init_error unless @exit_status.success?
    end

    def [](key)
      @internal_hash ||= parse_result
      @internal_hash[key]
    rescue => e
      raise PdfInfo::MetadataReadError.new(-1, e.message)
    end

    def encrypted?
      self['Encrypted'] != 'no'
    end

    def pages
      self['Pages'].to_i
    end

    def page_size
      width, height = self['Page size'].scan(/\d+/).map(&:to_i)
      { width:, height: }
    end

    def page_size_inches
      in_pts = page_size
      {
        height: convert_pts_to_inches(in_pts[:height]),
        width: convert_pts_to_inches(in_pts[:width])
      }
    end

    private

    def convert_pts_to_inches(dimension)
      dimension / 72.0
    end

    def init_error
      raise PdfInfo::MetadataReadError.new(@exit_status.exitstatus, @stdout.join('\n'))
    end

    def force_utf8_encoding(str)
      return str if str.valid_encoding?

      reencoded_str = str.encode(Encoding::UTF_16, invalid: :replace, undef: :replace, replace: '')
      reencoded_str.encode!(Encoding::UTF_8)
    end

    def parse_result
      @stdout.each_with_object({}) do |line, out|
        key, value = line.split(/:\s+/)
        out[key.strip] = value.try(:strip)
      end
    end
  end
end
