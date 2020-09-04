# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#index'
end
