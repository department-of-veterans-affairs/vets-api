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
    # OTP (One-Time Password) authentication endpoints
    post 'request-otp', to: 'sessions#request_otp'
    post 'authenticate-otp', to: 'sessions#authenticate_otp'
    post 'revoke-token', to: 'sessions#revoke_token'

    # Appointment management endpoints
    get 'appointment-availability', to: 'appointments#availability' # Get appointment availability for current cohort
    post 'appointment', to: 'appointments#create' # Create/book an appointment
    get 'appointment/:appointment_id', to: 'appointments#show' # Get appointment details
    post 'appointment/:appointment_id/cancel', to: 'appointments#cancel' # Cancel an appointment

    # Topics endpoint
    get 'topics', to: 'appointments#topics' # Get available appointment topics (agent skills)

    # API documentation endpoint
    get 'apidocs', to: 'apidocs#index'
  end
end
