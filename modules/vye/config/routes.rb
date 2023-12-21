# frozen_string_literal: true

Vye::Engine.routes.draw do
  namespace :v1, defaults: { format: 'json' } do
    resource :user_info, only: [:show], path: '/'
    resource :verifications, only: [:create], path: '/verify'
  end
end
