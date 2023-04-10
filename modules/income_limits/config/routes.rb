# frozen_string_literal: true

IncomeLimits::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    get 'limitsByZipCode/:zip/:year/:dependents', to: 'income_limits#index'
  end
end
