# frozen_string_literal: true

# VASS (VA Appointment Scheduling Service) API Routes
#
# This file defines the routing structure for the VASS v0 API.
# All routes are namespaced under /vass and return JSON by default.
#
# Available versions:
#   - v0: Initial version of the VASS API
#
Vass::Engine.routes.draw do
  # CORS preflight handling for v0 routes
  match '/vass/v0/*path', to: 'application#cors_preflight', via: [:options]

  # v0 namespace - Initial VASS API version
  # All responses default to JSON format
  namespace :v0, defaults: { format: :json } do
    # Session management endpoints
    resources :sessions, only: %i[show create]

    # Appointment management endpoints
    resources :appointments, only: %i[index show create]

    # API documentation endpoint
    get 'apidocs', to: 'apidocs#index'
  end
end
