# frozen_string_literal: true
class SFTPWriter::Remote
  def initialize(config, logger:)
    @config = config
    @logger = logger
  end

  def sftp
    @sftp ||= begin
      @logger.info('Connected to SFTP')
      Net::SFTP.start(
        @config.host,
        @config.user,
        password: @config.pass,
        port: @config.port
      )
    end
  end

  def close
    return unless sftp && sftp.open?
    @logger.info('Disconnected from SFTP')
    sftp.session.close
    true
  end

  def write_path
    @config.relative_path || nil
  end

  def write(contents, filename)
    sftp.upload!(StringIO.new(contents), File.join([write_path, filename].compact))
  end
end
