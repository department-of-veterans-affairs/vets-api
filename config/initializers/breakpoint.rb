# frozen_string_literal: true

# Only load `Breakpoint` when its only dependency, `Pry`, is loaded. If
# `Breakpoint` is ever deemed to have been loaded inappropriately, then the
# claim ought to instead be that `Pry` was loaded inappropriately. That's what
# we're expressing here.
return unless defined?(Pry)

module Breakpoint
  class << self
    # Add a breakpoint at the top of an instance's method:
    #   `Breakpoint.at_receiver(some_instance, :some_instance_method)`
    #
    # Add a breakpoint at the top of a class's method:
    #   `Breakpoint.at_receiver(SomeClass, :some_class_method)`
    def at_receiver(receiver, name)
      at_owner(receiver.singleton_class, name)
    end

    # Add a breakpoint at the top of a method for all of a class's instances:
    #   `Breakpoint.at_owner(SomeClass, :some_instance_method)`
    def at_owner(owner, name)
      owner.is_a?(Module) or
        raise ArgumentError, 'not an owner'

      mod =
        Module.new do
          define_method(name) do |*args, **kwargs, &block|
            # Now you have access to all the above arguments, plus whatever else
            # is available in the current environment.
            binding.pry # rubocop:disable Lint/Debugger
            super(*args, **kwargs, &block)
          end
        end

      owner.prepend(mod)
    end
  end
end

# Install breakpoints wherever you want if you need to investigate a particular
# instance during the execution of something, or even right here if you already
# have a handle on the thing you care about, like a class, e.g.:
# Breakpoint.at_receiver(Blueprinter::Base, :prepare_data)
