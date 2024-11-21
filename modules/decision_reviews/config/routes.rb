DecisionReviews::Engine.routes.draw do
  namespace :v1, defaults: { format: :json } do
    resources :nod_callbacks, only: [:create], controller: :decision_review_notification_callbacks
  end
end
