# frozen_string_literal: true
module EducationForm
  class Writer::Factory
    def self.get_writer
      if Rails.env.development? || Settings.edu.sftp.host.blank?
        EducationForm::Writer::Local
      elsif Settings.edu.sftp.pass.blank?
        raise "Settings.edu.sftp.pass not set for #{Settings.edu.sftp.user}@#{Settings.edu.sftp.host}"
      else
        EducationForm::Writer::Remote
      end
    end
  end
end
