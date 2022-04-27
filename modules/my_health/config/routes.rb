# frozen_string_literal: true

MyHealth::Engine.routes.draw do
  namespace :v1 do
    scope :messaging do
      resources :triage_teams, only: [:index], defaults: { format: :json }, path: 'recipients'

      resources :folders, only: %i[index show create destroy], defaults: { format: :json } do
        resources :messages, only: [:index], defaults: { format: :json }
      end

      resources :messages, only: %i[show create destroy], defaults: { format: :json } do
        get :thread, on: :member
        get :categories, on: :collection
        patch :move, on: :member
        post :reply, on: :member
        resources :attachments, only: [:show], defaults: { format: :json }
      end

      resources :message_drafts, only: %i[create update], defaults: { format: :json } do
        post ':reply_id/replydraft', on: :collection, action: :create_reply_draft, as: :create_reply
        put ':reply_id/replydraft/:draft_id', on: :collection, action: :update_reply_draft, as: :update_reply
      end

      resource :preferences, only: %i[show update], controller: 'messaging_preferences'
    end
  end
end
