# frozen_string_literal: true

require_relative 'client'

module Chip
  class Service
    attr_reader :tenant_name, :tenant_id, :username, :password, :client

    def initialize(opts)
      @tenant_name = opts[:tenant_name]
      @tenant_id = opts[:tenant_id]
      @username = opts[:username]
      @password = opts[:password]
      @client = Chip::Client.new(username:, password:)
      validate_arguments!
    end

    private

    def validate_arguments!
      raise ArgumentError, 'Invalid username' if username.blank?
      raise ArgumentError, 'Invalid password' if password.blank?
      raise ArgumentError, 'Invalid tenant parameters' if tenant_name.blank? || tenant_id.blank?
      raise ArgumentError, 'Tenant parameters do not exist' unless Chip::Client.configuration.valid_tenant?(
        tenant_name:, tenant_id:
      )
    end
  end
end
