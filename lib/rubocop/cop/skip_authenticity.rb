# frozen_string_literal: true

module RuboCop
  module Cop
    # Disallows the use of `skip_before_action :verify_authenticity_token`.
    #
    # Skipping CSRF protection can expose the application to cross-site
    # request forgery attacks. If you need to skip this for an API endpoint,
    # consider using a different authentication mechanism.
    #
    # @example
    #   # bad
    #   skip_before_action :verify_authenticity_token
    #
    class SkipAuthenticity < RuboCop::Cop::Base
      MSG = 'Do not skip authenticity token verification. ' \
            'This exposes the application to CSRF attacks.'

      RESTRICT_ON_SEND = %i[skip_before_action].freeze

      # Matches skip_before_action :verify_authenticity_token
      def_node_matcher :skip_authenticity_token?, <<~PATTERN
        (send nil? :skip_before_action (sym :verify_authenticity_token) ...)
      PATTERN

      def on_send(node)
        return unless skip_authenticity_token?(node)

        add_offense(node)
      end
    end
  end
end
