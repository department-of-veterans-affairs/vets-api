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
    dir = Rails.root.join('tmp', @config.relative_path.to_s)
    FileUtils.mkdir_p(dir)
    dir
  end

  def write(contents, filename)
    File.open(File.join(write_path, filename), 'w') do |f|
      f.write(contents)
    end
  end
end
