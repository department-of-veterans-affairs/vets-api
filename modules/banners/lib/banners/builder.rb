# frozen_string_literal: true

module Banners
  class Builder
    STATSD_KEY_PREFIX = 'banners.builder'

    def self.perform(banner_data)
      banner = new(banner_data).banner

      if banner.update(banner_data)
        log_success(banner_data[:entity_id])
        banner
      else
        log_failure(banner_data[:entity_id])
        false
      end
    end

    def initialize(banner_data)
      @banner_data = banner_data
    end

    def banner
      @banner ||= Banner.find_or_initialize_by(entity_id: banner_data[:entity_id])
    end

    attr_reader :banner_data

    private

    def self.log_failure(entity_id)
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure", tags: ["entitiy_id:#{entity_id}"])
    end

    def self.log_success(entity_id)
      StatsD.increment("#{STATSD_KEY_PREFIX}.success", tags: ["entitiy_id:#{entity_id}"])
    end

    private_class_method :log_failure, :log_success
  end
end
