# frozen_string_literal: true

module CovidResearch
  class Engine < ::Rails::Engine
    isolate_namespace CovidResearch
    config.generators.api_only = true
  end
end
