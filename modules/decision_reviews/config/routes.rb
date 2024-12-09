# frozen_string_literal: true

DecisionReviews::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    namespace :higher_level_reviews do
      get 'contestable_issues(/:benefit_type)', to: 'contestable_issues#index'
    end
    resources :higher_level_reviews, only: %i[create show]
  end
end
