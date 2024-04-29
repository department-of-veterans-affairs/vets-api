# frozen_string_literal: true

IvcChampva::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post '/forms', to: 'uploads#submit'
    post '/forms/submit_supporting_documents', to: 'uploads#submit_supporting_documents'
  end
end
