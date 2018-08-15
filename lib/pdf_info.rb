# frozen_string_literal: true

module PdfInfo
  class MetadataReadError < Exception
    def initialize(status, stdout)
      @status = status
      @stdout = stdout
    end
  end

  class Metadata
    def self.read(file_or_path)
      if file_or_path.is_a? String
        self.new(file_or_path, Settings.binaries.pdfinfo)
      else
        self.new(file_or_path.path, Settings.binaries.pdfinfo)
      end
    end

    def initialize(path, bin)
      @result = %x(#{bin} #{path})
      init_error unless $? == 0
    end

    def [](key)
      @internal_hash ||= parse_result
      @internal_hash[key]
    end

    def encrypted?
      return self['Encrypted'] == 'yes'
    end

    def pages
      return self['Pages'].to_i
    end

    private

    def init_error
      raise PdfInfo::MetadataReadError.new($?, @result)
    end

    def parse_result
      @result.split(/$/).reduce({}) do |out, line|
        key, value = line.split(/:\s+/)
        out[key.strip] = value.try(:strip)
        out
      end
    end
  end
end
