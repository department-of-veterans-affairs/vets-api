# frozen_string_literal: true
module EducationForm
  class Writer::Remote
    def sftp
      @sftp ||= Net::SFTP.start(ENV['EDU_SFTP_HOST'], ENV['EDU_SFTP_USER'], password: ENV['EDU_SFTP_PASS'])
    end

    def close
      sftp.close
      true
    end

    def write(contents, filename)
      sftp.upload!(StringIO.new(contents), filename)
    end
  end
end
