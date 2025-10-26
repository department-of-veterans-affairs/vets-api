# frozen_string_literal: true

SimpleFormsApi::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post '/simple_forms', to: 'uploads#submit'
    post '/simple_forms/submit_supporting_documents', to: 'uploads#submit_supporting_documents'
    get '/simple_forms/get_intents_to_file', to: 'uploads#get_intents_to_file'

    post '/submit_scanned_form', to: 'scanned_form_uploads#submit'
    post '/scanned_form_upload', to: 'scanned_form_uploads#upload_scanned_form'
    post '/supporting_documents_upload', to: 'scanned_form_uploads#upload_supporting_documents'

    resources :cemeteries, only: [:index]
  end
end
