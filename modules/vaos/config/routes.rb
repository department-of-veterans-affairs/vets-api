# frozen_string_literal: true

VAOS::Engine.routes.draw do
  namespace :v0, defaults: { format: 'json' } do
    get 'appointments', to: 'vaos#get_appointments'
  end
end
