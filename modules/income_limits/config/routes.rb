# frozen_string_literal: true

IncomeLimits::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    get 'limitsByZipCode/:zip/:year/:dependents', to: 'income_limits#index'
    get 'validateZipCode/:zip', to: 'income_limits#validate_zip_code'
  end
end
