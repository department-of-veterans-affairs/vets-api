# frozen_string_literal: true

module RuboCop
  module Cop
    module Project
      # Forbids using Flipper.enable/disable inside specs.
      #
      # Specs should use isolated feature managers or injected
      # flipper instances instead of mutating global state.
      #
      class ForbidFlipperToggleInSpecs < Base
        MSG = 'Avoid using Flipper.enable/disable in specs. Use an isolated flipper instance instead.'

        RESTRICT_ON_SEND = %i[enable disable].freeze

        def on_send(node)
          return unless in_spec_file?
          return unless flipper_call?(node)

          add_offense(node.loc.selector)
        end

        private

        def flipper_call?(node)
          receiver = node.receiver
          return false unless receiver&.const_type?

          receiver.const_name == 'Flipper'
        end

        def in_spec_file?
          processed_source.file_path.include?('/spec/')
        end
      end
    end
  end
end
