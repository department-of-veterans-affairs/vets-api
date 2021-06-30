# frozen_string_literal: true

module Mobile
  class ServiceNode
    attr_accessor :name, :dependent_services

    def initialize(name:)
      @name = name
      @dependent_services = []
    end

    def add_service(service)
      @dependent_services << service
    end

    def leaf?
      @dependent_services.blank?
    end
  end
end
