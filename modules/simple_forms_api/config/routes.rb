# frozen_string_literal: true

SimpleFormsApi::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    post '/simple_forms', to: 'uploads#submit'
    post '/simple_forms/submit_supporting_documents', to: 'uploads#submit_supporting_documents'
    get '/simple_forms/get_intents_to_file', to: 'uploads#get_intents_to_file'
  end
end
