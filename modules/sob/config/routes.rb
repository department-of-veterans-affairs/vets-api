# frozen_string_literal: true

SOB::Engine.routes.draw do
  namespace :v2, defaults: { format: :json } do
    resource :post911_gi_bill_status, only: [:show]
  end
end
