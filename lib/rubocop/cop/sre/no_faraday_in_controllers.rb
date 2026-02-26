# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 14 - No Faraday exception rescue in controllers.
      #
      # Controllers should not rescue Faraday errors directly. Transport-level
      # exceptions should be caught in service/client layers and translated into
      # domain-specific errors before reaching the controller.
      #
      # @example
      #   # bad (in a controller)
      #   rescue Faraday::TimeoutError => e
      #   rescue Faraday::ClientError, Faraday::ConnectionFailed => e
      #
      #   # good (in a service layer)
      #   rescue Faraday::TimeoutError => e
      #     raise MyService::UpstreamTimeout, e.message
      class NoFaradayInControllers < Base
        MSG = '[Play 14] Controller rescues `%<name>s` directly. ' \
              'Catch transport errors in the service layer and re-raise as domain errors.'

        def on_resbody(node)
          return unless in_controller?

          exception_classes = node.children[0]
          return unless exception_classes

          each_exception_class(exception_classes) do |const_node|
            next unless faraday_const?(const_node)

            add_offense(const_node, message: format(MSG, name: const_node.source))
          end
        end

        private

        def in_controller?
          processed_source.file_path.include?('/controllers/')
        end

        def each_exception_class(node, &)
          if node.array_type?
            node.children.each { |child| yield child if child.const_type? }
          elsif node.const_type?
            yield node
          end
        end

        def faraday_const?(node)
          return false unless node.const_type?

          # Walk up the const chain looking for :Faraday as the root
          current = node
          while current&.const_type?
            return true if current.children[1] == :Faraday && current.children[0].nil?

            current = current.children[0]
          end
          false
        end
      end
    end
  end
end
