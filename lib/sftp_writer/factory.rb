# frozen_string_literal: true

require_relative 'local'
require_relative 'remote'

module SFTPWriter
  class Factory
    def self.get_writer(config)
      if Rails.env.development? || config.host.blank?
        SFTPWriter::Local
      elsif config.key_path.blank? || config.key_data.blank?
        raise "SFTP cert not present for #{config.user}@#{config.host}:#{config.port}"
      else
        SFTPWriter::Remote
      end
    end
  end
end
