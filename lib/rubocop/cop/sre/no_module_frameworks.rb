# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 10 - No local error/logging frameworks in modules.
      #
      # Modules should use the platform's standard error handling and logging
      # infrastructure. Custom `LogService`, `ErrorHandler` classes, or
      # `handle_error`/`handle_exception` methods create inconsistency and
      # make centralized observability harder.
      #
      # @example
      #   # bad (in modules/)
      #   class MyModule::ErrorHandler
      #   class MyModule::LogService
      #   def handle_error(e)
      #
      #   # good
      #   # Use Rails.logger, Common::Exceptions, etc.
      class NoModuleFrameworks < Base
        MSG_CLASS = '[Play 10] Custom `%<name>s` in a module duplicates platform infrastructure. ' \
                    'Use standard error handling (Common::Exceptions, Rails.logger).'
        MSG_METHOD = '[Play 10] `%<name>s` method suggests a local error framework. ' \
                     'Use standard platform error handling.'

        FRAMEWORK_CLASS_SUFFIXES = %w[LogService ErrorHandler].freeze
        FRAMEWORK_METHOD_NAMES = %i[handle_error handle_exception].freeze

        def on_class(node)
          return unless in_modules_dir?

          class_name = node.children[0]&.short_name&.to_s
          return unless class_name

          suffix = FRAMEWORK_CLASS_SUFFIXES.find { |s| class_name.end_with?(s) }
          return unless suffix

          add_offense(node, message: format(MSG_CLASS, name: class_name))
        end

        def on_def(node)
          return unless in_modules_dir?
          return unless FRAMEWORK_METHOD_NAMES.include?(node.method_name)

          add_offense(node, message: format(MSG_METHOD, name: node.method_name))
        end

        private

        def in_modules_dir?
          path = processed_source.file_path
          path.include?('/modules/') || path.start_with?('modules/')
        end
      end
    end
  end
end
