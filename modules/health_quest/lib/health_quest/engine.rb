# frozen_string_literal: true

module HealthQuest
  class Engine < ::Rails::Engine
    isolate_namespace HealthQuest
    config.generators.api_only = true
  end
end
