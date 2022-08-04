# frozen_string_literal: true

DhpConnectedDevices::Engine.routes.draw do
  get '/apidocs', to: 'apidocs#index'
  get '/veteran-device-records', to: 'veteran_device_records#index'

  scope module: 'fitbit' do
    get 'fitbit', to: 'fitbit#connect'
    get 'fitbit-callback', to: 'fitbit#callback'
    get 'fitbit/disconnect', to: 'fitbit#disconnect'
  end
end
