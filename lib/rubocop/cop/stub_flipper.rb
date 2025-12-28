# frozen_string_literal: true

module RuboCop
  module Cop
    # Enforces using `allow(Flipper).to receive(:enabled?)` instead of
    # `Flipper.enable` or `Flipper.disable` in specs.
    #
    # Using Flipper.enable/disable in tests can cause state to leak between
    # test examples. Stubbing with allow(Flipper) ensures isolation.
    #
    # @example
    #   # bad
    #   Flipper.enable(:feature_flag)
    #   Flipper.disable(:feature_flag)
    #
    #   # good
    #   allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)
    #   allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(false)
    #
    class StubFlipper < RuboCop::Cop::Base
      MSG = 'Use `allow(Flipper).to receive(:enabled?)` instead of `Flipper.enable/disable` in specs'

      RESTRICT_ON_SEND = %i[enable disable].freeze

      # Matches Flipper.enable(:feature) or Flipper.disable(:feature)
      def_node_matcher :flipper_enable_disable?, <<~PATTERN
        (send (const nil? :Flipper) {:enable :disable} ...)
      PATTERN

      def on_send(node)
        return unless flipper_enable_disable?(node)

        add_offense(node)
      end
    end
  end
end
