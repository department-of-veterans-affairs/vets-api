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

    resources :claims, only: [:index]

    get 'welcome', to: 'example#welcome', as: :welcome
    get 'status', to: 'admin#status'
  end

  namespace :rx, defaults: {format: 'json'} do
  namespace :v1 do
    resources :prescriptions, only: [:index, :show], defaults: { format: :json } do
      get :active, to: "prescriptions#index", on: :collection, defaults: { refill_status: 'active' }
      # Note: refill should be POST or PATCH, but never put since it is non indempotent
      # Patch technically makes more sense since we're returning no content, 204 response
      # reference: http://www.restapitutorial.com/lessons/httpmethods.html
      patch :refill, to: "prescriptions#refill", on: :member
      resources :trackings, only: :index, controller: :trackings
    end
  end
end

  root 'v0/example#index', module: 'v0'
end
