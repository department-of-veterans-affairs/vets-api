# frozen_string_literal: true
module EducationForm
  class Writer::Remote
    def initialize(logger:)
      @logger = logger
    end

    def sftp
      @sftp ||= begin
        @logger.info('Connected to SFTP')
        Net::SFTP.start(
          Settings.edu.sftp.host,
          Settings.edu.sftp.user,
          password: Settings.edu.sftp.pass,
          port: Settings.edu.sftp.port
        )
      end
    end

    def close
      return unless sftp && sftp.open?
      @logger.info('Disconnected from SFTP')
      sftp.session.close
      true
    end

    def write(contents, filename)
      sftp.upload!(StringIO.new(contents), filename)
    end
  end
end
