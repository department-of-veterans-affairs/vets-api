# frozen_string_literal: true

BioHeartApi::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post '/bio_heart', to: 'uploads#submit'
  end
end
