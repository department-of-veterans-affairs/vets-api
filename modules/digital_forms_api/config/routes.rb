# frozen_string_literal: true

DigitalFormsApi::Engine.routes.draw do
  resources :submissions, only: :show, defaults: { format: :json }
end
