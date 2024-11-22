LoadTesting::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :test_sessions, only: [:create, :show, :index] do
      member do
        get :analysis
        get 'tokens/next', to: 'tokens#next'
      end
    end
    
    get 'config', to: 'config#show'
    get 'metrics', to: 'metrics#index'
  end
end 