AppealsApi::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]

  namespace :v0, defaults: { format: 'json' } do
    resources :appeals, only: [:index]
  end

  namespace :docs do
    namespace :v0 do
      resources :api, only: [:index]
    end
  end
end
