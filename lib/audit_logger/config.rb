# frozen_string_literal: true

require 'audit_logger/storage/mongo_adapter'
module AuditLogger
  class Config
    attr_reader :adapter

    def adapter=(adapter_type)
      @adapter = create_adapter_config(adapter_type)
    end

    def validate!
      raise ArgumentError, 'Adapter is not set' if adapter.nil?

      adapter.validate!
    end

    private

    def create_adapter_config(adapter_type)
      case adapter_type
      when :mongo
        AuditLogger::Storage::MongoAdapter.new
      end
    end
  end
end
