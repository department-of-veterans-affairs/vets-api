# frozen_string_literal: true

MockedAuthentication::Engine.routes.draw do
  namespace :mpi do
    resources :mockdata, only: :show, param: :icn
  end

  unless Settings.vsp_environment == 'staging'
    get '/authorize', to: 'credential#authorize'
    get '/credential_list', to: 'credential#credential_list'
  end
end
