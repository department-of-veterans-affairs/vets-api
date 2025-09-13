# frozen_string_literal: true

VRE::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :claims, only: [:create]
    resource :ch31_eligibility_status, only: [:show]
  end
end
