# frozen_string_literal: true

DhpConnectedDevices::Engine.routes.draw do
  get '/fitbit', to: 'fitbit#connect'
  get '/apidocs', to: 'apidocs#index'
  get '/fitbit-callback', to: 'fitbit#callback'
  get '/veteran-device-records', to: 'veteran_device_records#index'
  get '/fitbit/disconnect', to: 'fitbit#disconnect'
end
