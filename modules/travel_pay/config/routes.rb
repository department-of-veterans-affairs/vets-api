# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  namespace :v0 do
    resources :claims, only: %i[index show create]

    scope '/claims/:claim_id', constraints: { claim_id: %r{[^/]+} } do
      resources :documents, only: %i[index show create destroy]
      post 'expenses/:expense_type', to: 'expenses#create', constraints: { expense_type: %r{[^/]+} }
      get 'expenses/:expense_type/:expense_id', to: 'expenses#show',
                                                constraints: { expense_type: %r{[^/]+}, expense_id: %r{[^/]+} }
    end
    # NOTE: The DELETE and PATCH expense endpoints do NOT require a claim_id in the Travel Pay API.
    # For that reason, these routes are NOT scoped under /claims/:claim_id.
    delete 'expenses/:expense_type/:expense_id', to: 'expenses#destroy',
                                                 constraints: { expense_type: %r{[^/]+}, expense_id: %r{[^/]+} }

    patch 'expenses/:expense_type/:expense_id', to: 'expenses#update',
                                                constraints: { expense_type: %r{[^/]+}, expense_id: %r{[^/]+} }

    resources :complex_claims, only: %i[create], param: :claim_id do
      member do
        patch :submit
      end
    end
  end
end
