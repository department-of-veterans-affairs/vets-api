# frozen_string_literal: true

class SFTPWriter::Local
  def initialize(config, logger:)
    @config = config
    @logger = logger
  end

  def close
    true
  end

  def write_path
    Rails.root.join('tmp', @config.relative_path.to_s)
  end

  def write(contents, filename)
    path = File.join(write_path, filename)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'wb') do |f|
      f.write(contents)
    end
  end
end
