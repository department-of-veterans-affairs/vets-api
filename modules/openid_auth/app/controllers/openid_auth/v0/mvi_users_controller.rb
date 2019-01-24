# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class MviUsersController < ApplicationController
      skip_before_action :authenticate

      def show
        user_identity = UserIdentity.create(uuid: request.headers['x-va-ssn'],
                                            email: params['user_email'],
                                            first_name: request.headers['x-va-first-name'],
                                            last_name: request.headers['x-va-last-name'],
                                            birth_date: request.headers['x-va-dob'],
                                            ssn: request.headers['x-va-ssn'],
                                            loa:
                                              { current: params[:loa][:current].to_i, highest: params[:loa][:highest].to_i }
                                           )
        user = User.new user_identity
        Mvi.for_user(user)
        if user.icn.present?
          render json:
          {
            "id": user.icn,
            "type": 'user-mvi-icn',
            "data": {
              "attributes": {
                "icn": user.icn
              }
            }
          }
        else
          render json:
          {
            "id": user.icn,
            "type": 'user-mvi-icn',
            "data": {
              "errors": {
                "icn": 'could not locate ICN'
              }
            }
          }
        end
      end

      private

      def validated_payload
        @validated_payload ||= OpenStruct.new(token_payload.merge(va_identifiers: { icn: @current_user.icn }))
      end
    end
  end
end
