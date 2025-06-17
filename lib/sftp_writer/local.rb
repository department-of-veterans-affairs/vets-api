# frozen_string_literal: true

module SFTPWriter
  class Local
    def initialize(config, logger:)
      @config = config
      @logger = logger
    end

    def close
      true
    end

    def write_path(_filename)
      Rails.root.join('tmp', @config.relative_path.to_s)
    end

    def write(contents, filename)
      path = File.join(write_path(filename), filename)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, contents)
      0
    end
  end
end
