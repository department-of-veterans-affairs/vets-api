# frozen_string_literal: true

module MyHealth
  class Engine < ::Rails::Engine
    isolate_namespace MyHealth
    config.generators.api_only = true
  end
end
