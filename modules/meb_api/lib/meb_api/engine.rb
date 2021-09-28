# frozen_string_literal: true

module MebApi
  class Engine < ::Rails::Engine
    isolate_namespace MebApi
    config.generators.api_only = true
  end
end
