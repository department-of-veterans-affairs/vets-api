# frozen_string_literal: true
require 'fileutils'

class SFTPWriter::Remote
  def initialize(config, logger:)
    @config = config
    @logger = logger
  end

  def sftp
    @sftp ||= begin
      @logger.info('Connecting to SFTP')
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
    path = File.join([write_path,filename].compact)
    mkdir_safe(path)
    sftp.upload!(StringIO.new(contents), path)
  end

  private
  def mkdir_safe(path)
    path = Pathname.new(path)
    dir = path.dirname
    dirs = Array(dir.descend.to_a[2..-1])
    dirs.each do |f|
      begin
        sftp.mkdir!(f)
      rescue Net::SFTP::StatusException
        raise if $!.code != Net::SFTP::Constants::StatusCodes::FX_FILE_ALREADY_EXISTS
      end
    end
  end
end
