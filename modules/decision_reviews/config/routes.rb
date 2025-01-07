# frozen_string_literal: true

DecisionReviews::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    namespace :higher_level_reviews do
      get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
    end
    resources :higher_level_reviews, only: %i[create show]

    namespace :notice_of_disagreements do
      get 'contestable_issues', to: 'contestable_issues#index'
    end
    resources :notice_of_disagreements, only: %i[create show]

    namespace :supplemental_claims do
      get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
    end
    resources :supplemental_claims, only: %i[create show]

    resource :decision_review_evidence, only: :create

    scope format: false do
      resources :nod_callbacks, only: [:create], controller: :decision_review_notification_callbacks
    end
  end

  namespace :v2, defaults: { format: 'json' } do
    resources :higher_level_reviews, only: %i[create show]
  end
end
