Rails.application.routes.draw do

  namespace :v0, defaults: {format: 'json'} do
    get 'status', to: 'admin#status'
  end

end
