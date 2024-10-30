# frozen_string_literal: true

VaNotify::Engine.routes.draw do
  post '/callbacks', to: 'callbacks#create'
end
