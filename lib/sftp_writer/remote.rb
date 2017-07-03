# frozen_string_literal: true
class SFTPWriter::Remote
  def initialize(config, logger:)
    @config = config
    @logger = logger
  end

  def sftp
    @sftp ||=
      Net::SFTP.start(
        @config.host,
        @config.user,
        password: @config.pass,
        port: @config.port
      )
    @logger.info('Connecting to SFTP')
    @sftp
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
    path = File.join([write_path, filename].compact)
    mkdir_safe(path)
    sftp.upload!(StringIO.new(contents), path)
  end

  private

  # The Net::SFTP library handles making recursive paths really poorly:
  # You can either upload and sync an entire directory, in which case it
  # will make any missing foldes... and also raise errors if any folders
  # in the path already exist.
  # Or you can upload files into a single root directory
  # Or you can do something like this.
  def mkdir_safe(path)
    dir = Pathname.new(path).dirname
    # phew boy this is brittle.
    dirs = Array(dir.descend.to_a)
    dirs.pop(2) if dirs[0] == '/'
    dirs.each do |f|
      begin
        sftp.mkdir!(f.to_s)
      rescue Net::SFTP::StatusException
        raise if $ERROR_INFO.code != Net::SFTP::Constants::StatusCodes::FX_FILE_ALREADY_EXISTS
      end
    end
  end
end
