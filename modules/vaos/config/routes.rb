# frozen_string_literal: true

VAOS::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    get 'systems', to: 'vaos#get_systems'
    get 'api', to: 'apidocs#index'
  end
end
