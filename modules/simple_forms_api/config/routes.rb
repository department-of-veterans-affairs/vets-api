# frozen_string_literal: true

SimpleFormsApi::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post '/simple_forms', to: 'uploads#submit'
  end
end
