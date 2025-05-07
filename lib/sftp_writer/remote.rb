# frozen_string_literal: true

module SFTPWriter
  class Remote
    def initialize(config, logger:)
      @config = config
      @logger = logger
    end

    def sftp
      @sftp ||= begin
        key_data = @config.key_data.presence || File.read(@config.key_path)
        Net::SFTP.start(
          @config.host,
          @config.user,
          port: @config.port,
          key_data: [key_data]
        )
      end
      @sftp
    end

    def close
      return unless @sftp && sftp.open?

      @logger.info('Disconnected from SFTP')
      sftp.session.close
      true
    end

    def write_path(filename)
      if filename.starts_with?('307_')
        @config.relative_307_path || @config.relative_path || nil
      elsif filename.starts_with?('351_')
        @config.relative_351_path || @config.relative_path || nil
      else
        @config.relative_path || nil
      end
    end

    def write(contents, filename)
      path = File.join([write_path(filename), sanitize(filename)].compact)
      @logger.info("Writing #{path}")

      # only sftp on production. There were repeated issues with test data getting into TIMS
      # The decision was made to push spool files only on production
      bytes_sent = 0

      if Settings.hostname.eql?('api.va.gov') || @config.allow_staging_uploads
        mkdir_safe(path)
        sftp.upload!(StringIO.new(contents), path)

        # get the file size from the remote destination
        begin
          bytes_sent = sftp.stat!(path)&.size || 0
        rescue Net::SFTP::StatusException # This will happen if nothing got sent
          bytes_sent = 0
        end
      end

      bytes_sent
    end

    private

    # The Net::SFTP library handles making recursive paths really poorly:
    # You can either upload and sync an entire directory, in which case it
    # will make any missing folders... and also raise errors if any folders
    # in the path already exist.
    # Or you can upload files into a single root directory
    # Or you can do something like this.
    def mkdir_safe(path)
      dir = Pathname.new(path).dirname
      dirs = Array(dir.descend.to_a)
      # If we're using an absolute path, we can/should trust that the base folder
      # already exists. Remove `/` and `/BASE_FOLDER` from the list of things to
      # create -- they typically won't be our user, and so we'll hit a permission
      # error.
      dirs.shift(2) if dirs[0].to_s == '/'
      dirs.each do |f|
        sftp.mkdir!(f.to_s)
      rescue Net::SFTP::StatusException
        raise if $ERROR_INFO.code != Net::SFTP::Constants::StatusCodes::FX_FILE_ALREADY_EXISTS
      end
    end

    def sanitize(filename)
      filename.tr(':', '_')
    end
  end
end
