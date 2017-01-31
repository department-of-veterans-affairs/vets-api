# frozen_string_literal: true
module EducationForm
  class Writer::Factory
    def self.get_writer
      if Rails.env.development? || ENV['EDU_SFTP_HOST'].blank?
        EducationForm::Writer::Local
      elsif ENV['EDU_SFTP_PASS'].blank?
        raise "EDU_SFTP_PASS not set for #{ENV['EDU_SFTP_USER']}@#{ENV['EDU_SFTP_HOST']}"
      else
        EducationForm::Writer::Remote
      end
    end
  end
end
