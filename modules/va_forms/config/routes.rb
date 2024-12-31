# frozen_string_literal: true

VAForms::Engine.routes.draw do
  match '/v0/*path', to: 'application#cors_preflight', via: [:options]
end
