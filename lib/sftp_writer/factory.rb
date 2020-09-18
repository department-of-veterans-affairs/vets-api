# frozen_string_literal: true

require_relative 'local'
require_relative 'remote'

module SFTPWriter
  class Factory
    def self.get_writer(config)
      if Rails.env.development? || config.host.blank?
        SFTPWriter::Local
      elsif config.pass.blank?
        raise "SFTP password not set for #{config.user}@#{config.host}:#{config.port}"
      else
        SFTPWriter::Remote
      end
    end
  end
end
