# frozen_string_literal: true

module Banners
  class Builder
    # TODO: Adjust perform to log appropriate messages
    def self.perform(banner_data)
      banner = new(banner_data).banner
      puts "got banner data: #{banner_data}"
      banner.update!(banner_data)
    end

    def initialize(banner_data)
      @banner_data = banner_data
    end

    def banner
      @banner ||= Banner.find_or_initialize_by(entity_id: banner_data[:entity_id])
    end

    attr_reader :banner_data
  end
end
