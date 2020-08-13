# frozen_string_literal: true

HealthQuest::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    get 'hello_world', to: 'healthquest#index'
  end
end
