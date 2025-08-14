# frozen_string_literal: true

module RuboCop
  module Cops
    module Custom
      # Disallow using instance variables in spec files.
      #
      # @example
      #   # bad
      #   before do
      #     @user = create(:user)
      #   end
      #
      #   # good
      #   let(:user) { create(:user) }
      #
      class NoInstanceVarsInSpecs < RuboCop::Cop::Base
        MSG = 'Do not use instance variables in specs. Use `let` instead.'

        def on_ivasgn(node)
          return unless in_spec_file?(node)

          add_offense(node, message: MSG)
        end

        def on_ivar(node)
          return unless in_spec_file?(node)

          add_offense(node, message: MSG)
        end

        private

        def in_spec_file?(_node)
          path = processed_source.buffer.name
          path.match?(%r{/(spec|modules/[^/]+/spec)/})
        end
      end
    end
  end
end
