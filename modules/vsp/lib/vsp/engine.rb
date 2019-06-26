# frozen_string_literal: true

module Vsp
  class Engine < ::Rails::Engine
    isolate_namespace Vsp
    config.generators.api_only = true
  end
end
