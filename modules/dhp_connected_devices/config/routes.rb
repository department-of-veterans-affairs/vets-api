# frozen_string_literal: true

DhpConnectedDevices::Engine.routes.draw do
  get '/fitbit', to: 'fitbit#connect'
  get 'apidocs', to: 'apidocs#index'
end
