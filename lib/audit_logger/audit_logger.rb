# frozen_string_literal: true

require 'audit_logger/config'

module AuditLogger
  class << self
    delegate :adapter, to: :config
    delegate :client, to: :adapter

    attr_accessor :config # rubocop:disable ThreadSafety/ClassAndModuleAttributes

    def configure
      self.config ||= Config.new
      yield(config)
      config.validate!
    end

    def log(log)
      adapter.write(log)
    end

    def find(query)
      adapter.read(query)
    end
  end
end
