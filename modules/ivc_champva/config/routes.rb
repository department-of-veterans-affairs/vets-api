# frozen_string_literal: true

IvcChampva::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post '/forms', to: 'uploads#submit'
    post '/forms/10-10d-ext', to: 'uploads#submit_champva_app_merged'
    post '/forms/submit_supporting_documents', to: 'uploads#submit_supporting_documents'
    post '/forms/status_updates', to: 'pega#update_status'
  end
end
