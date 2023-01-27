# frozen_string_literal: true

FormsApi::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post '/submit', to: 'uploads#submit'
  end
end
