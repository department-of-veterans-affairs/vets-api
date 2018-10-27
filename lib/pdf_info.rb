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
        new(file_or_path, Settings.binaries.pdfinfo)
      else
        new(file_or_path.path, Settings.binaries.pdfinfo)
      end
    end

    def initialize(path, bin)
      @stdout = []
      Open3.popen2e([bin, 'argv0'], path) do |_stdin, stdout, wait|
        @exit_status = wait.value
        stdout.each_line do |line|
          @stdout.push(force_utf8_encoding(line))
        end
      end
      init_error unless @exit_status.success?
    end

    def [](key)
      @internal_hash ||= parse_result
      @internal_hash[key]
    rescue StandardError => e
      raise PdfInfo::MetadataReadError.new(-1, e.message)
    end

    def encrypted?
      self['Encrypted'] != 'no'
    end

    def pages
      self['Pages'].to_i
    end

    private

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
