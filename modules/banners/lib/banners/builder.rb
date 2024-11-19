module Banners
    class Builder
        # TODO: Add logic to build banners, this needs #perform and #perform_async methods
        #      to be implemented that will find or create a banner based on the data passed in
        def self.perform(banner_data)
            banner = new(banner_data).banner
            puts "got banner data: #{banner_data}"
            banner.update!(banner_data)
        end

        def self.perform_async(banner_data)
            banner = new(banner_data).banner
            @banner_data = banner_data
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