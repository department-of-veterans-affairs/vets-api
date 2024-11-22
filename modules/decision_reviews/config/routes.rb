# frozen_string_literal: true

DecisionReviews::Engine.routes.draw do
  namespace :v1, defaults: { format: :json } do
    resources :notice_of_disagreements, only: %i[create show]

    resource :decision_review_evidence, only: :create

    resources :nod_callbacks, only: [:create], controller: :decision_review_notification_callbacks
  end
end
