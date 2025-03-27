# frozen_string_literal: true

module Mobile
  module V0
    class ServiceGraph
      attr_accessor :services

      MAINTENANCE_WINDOW_NAMESPACE = 'fa1a248e-0f71-4077-8d25-ed7430bcdb34'

      def initialize(*graph)
        @services = {}

        graph.each do |service|
          upstream = service.first
          downstream = service.last
          @services[upstream] = ServiceNode.new(name: upstream) unless @services[upstream]
          @services[downstream] = ServiceNode.new(name: downstream) unless @services[downstream]
          link_service(upstream, downstream)
        end
      end

      delegate :[], to: :@services

      def affected_services(windows)
        downstream_windows = {}

        windows.each do |window|
          name = window.external_service.to_sym
          queue = []
          queue.push(@services[name])

          while queue.size != 0
            s = queue.shift
            dss = downstream_windows[s&.name]
            if s && s.name != name && s.leaf? && (dss.nil? || window.start_time < dss&.start_time)
              downstream_windows[s.name] =
                create_or_update_window(s.name, window)
            end
            s&.dependent_services&.each do |ds|
              queue.push(ds)
            end
          end
        end

        downstream_windows
      end

      private

      def link_service(upstream_name, downstream_name)
        raise "could not find upstream service '#{upstream_name}'" unless @services[upstream_name]
        raise "could not find downstream service '#{downstream_name}'" unless @services[downstream_name]

        @services[upstream_name].add_service(@services[downstream_name])
      end

      def create_or_update_window(downstream_name, update_window)
        start_time = update_window.start_time
        end_time = update_window.end_time
        description = update_window.description

        MaintenanceWindow.new(
          id: Digest::UUID.uuid_v5(MAINTENANCE_WINDOW_NAMESPACE, downstream_name.to_s),
          service: downstream_name,
          start_time:,
          end_time:,
          description:
        )
      end
    end
  end
end
