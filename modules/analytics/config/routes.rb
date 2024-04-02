# frozen_string_literal: true

Analytics::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    get '/user/hashes', to: 'hashes#index'
  end
end
