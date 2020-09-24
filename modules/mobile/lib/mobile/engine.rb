# frozen_string_literal: true

module Mobile
  class Engine < ::Rails::Engine
    isolate_namespace Mobile
    config.generators.api_only = true
  end
end
