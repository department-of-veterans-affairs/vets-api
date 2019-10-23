# frozen_string_literal: true

module VAOS
  class Engine < ::Rails::Engine
    isolate_namespace VAOS
    config.generators.api_only = true
  end
end
