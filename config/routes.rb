Rails.application.routes.draw do

  get '/saml/metadata', to: 'saml#metadata'
  get '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'
  post '/auth/saml/callback', to: 'v0/sessions#saml_callback', module: 'v0'

  namespace :v0, defaults: {format: 'json'} do
    resource :sessions, only: [:new, :destroy] do
      get :saml_callback, to: 'sessions#saml_callback'
      get 'profile', to: 'sessions#show'
    end

    resource :users, only: :show

    resource :education_benefits_claims, only: :create
    resources :claims, only: [:index]

    get 'welcome', to: 'example#welcome', as: :welcome
    get 'status', to: 'admin#status'
  end

  root 'v0/example#index', module: 'v0'
end
