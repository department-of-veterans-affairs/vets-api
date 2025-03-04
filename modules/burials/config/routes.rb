# frozen_string_literal: true

Burials::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :claims, only: %i[create show] if Settings.central_mail.upload.enabled
  end
end
