# frozen_string_literal: true

FORM_526_SUBFORMS = %w[4142 0781 8940].freeze

ClaimsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :claims, only: %i[index show]
    namespace :forms do
      ## 526 Forms
      post '526', to: 'disability_compensation#form_526'
      FORM_526_SUBFORMS.each do |sub_form|
        post "526/:id/#{sub_form}", to: "disability_compensation#form_#{sub_form}"
      end
    end
  end

  namespace :docs do
    namespace :v0 do
      get 'api', to: 'api#claims'
    end
  end
end
