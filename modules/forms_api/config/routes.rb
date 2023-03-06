# frozen_string_literal: true

FormsApi::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post '/simple_forms', to: 'uploads#submit'
  end
end
