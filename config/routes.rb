Rails.application.routes.draw do

  scope module: 'v0' do
    root 'admin#index'
  end

  namespace :v0, defaults: {format: 'json'} do
    get 'status', to: 'admin#status'
  end

end
