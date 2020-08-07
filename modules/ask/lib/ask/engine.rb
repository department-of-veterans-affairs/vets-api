# frozen_string_literal: true

module Ask
  class Engine < ::Rails::Engine
    isolate_namespace Ask
    config.generators.api_only = true
  end
end
