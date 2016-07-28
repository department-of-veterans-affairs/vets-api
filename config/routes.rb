Rails.application.routes.draw do

  get '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'

  namespace :v0, defaults: {format: 'json'} do
    resource :sessions

    get 'welcome', to: 'example#welcome', as: :welcome
    get 'profile', to: 'sessions#show'
    get 'status', to: 'admin#status'
  end

  root 'v0/example#index', module: 'v0'
end
