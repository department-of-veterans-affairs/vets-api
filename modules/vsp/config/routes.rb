# frozen_string_literal: true

Vsp::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    get 'hello_world', to: 'hello_world#index'
  end
end
