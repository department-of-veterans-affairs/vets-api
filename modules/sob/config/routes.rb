# frozen_string_literal: true

SOB::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resource :ch31_status, only: [:show]
  end
end
