# frozen_string_literal: true

module CustomCops
  class EnforceSidekiqPolicy < RuboCop::Cop::Cop
    def_node_search :sidekiq_job?, <<~PATTERN
      (send nil? :include (const (const nil? :Sidekiq) :Job))
    PATTERN

    def_node_search :retry_option?, <<~PATTERN
      (send nil? :sidekiq_options (hash <(pair (sym :retry) _) ...>))
    PATTERN

    def_node_search :retries_exhausted_block?, <<~PATTERN
      (block (send nil? :sidekiq_retries_exhausted) ...)
    PATTERN

    def on_class(node)
      return unless sidekiq_job?(node)

      retry_option = retry_option?(node.body)
      exhausted_block = retries_exhausted_block?(node.body)

      if retry_option
        retries_disabled = node.body.children.find { |n| n.type == :send && n.method_name == :sidekiq_options }
                               .arguments.first.children.find { |n| n.type == :pair && n.children[0].value == :retry }
                               .children[1].type == :false # rubocop:disable Lint/BooleanSymbol
        return if retries_disabled

        unless exhausted_block
          add_offense(node, message: 'Ensure Sidekiq jobs define a sidekiq_retries_exhausted block.')
        end
      else
        add_offense(node, message: 'Ensure Sidekiq jobs define a retry policy (integer or false).')
      end
    end
  end
end
