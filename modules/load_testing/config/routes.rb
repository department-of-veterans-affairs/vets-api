LoadTesting::Engine.routes.draw do
  namespace :v0 do
    resources :test_sessions do
      member do
        get :analysis
        get :tokens
      end
    end
  end
end 