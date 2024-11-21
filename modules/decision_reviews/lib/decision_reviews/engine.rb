# frozen_string_literal: true

module DecisionReviews
  class Engine < ::Rails::Engine
    isolate_namespace DecisionReviews
    config.generators.api_only = true
  end
end
