# frozen_string_literal: true

Ask::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    get 'hello_world', to: 'ask#index'
  end
end
