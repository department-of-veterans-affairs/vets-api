# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class MviUsersController < ApplicationController
      skip_before_action :authenticate
      before_action :check_required_headers

      def show
        if request.headers['x-va-ssn'].present?
          build_ssn_user
        else
          build_edipi_user
        end
        @user = User.new @user_identity
        Mvi.for_user(@user)

        if @user.icn.present?
          icn_found
        else
          icn_not_found
        end
      end

      private

      def build_edipi_user
        @user_identity = UserIdentity.create(uuid: request.headers['x-va-edipi'],
                                             email: request.headers['x-va-user-email'],
                                             ssn: request.headers['x-va-edipi'],
                                             loa:
                                             {
                                               current: request.headers['x-va-level-of-assurance'].to_i,
                                               highest: highest_loa
                                             })
      end

      def build_ssn_user
        @user_identity = UserIdentity.create(uuid: request.headers['x-va-ssn'],
                                             email: request.headers['x-va-user-email'],
                                             first_name: request.headers['x-va-first-name'],
                                             last_name: request.headers['x-va-last-name'],
                                             birth_date: request.headers['x-va-dob'],
                                             ssn: request.headers['x-va-ssn'],
                                             loa:
                                             {
                                               current: request.headers['x-va-level-of-assurance'].to_i,
                                               highest: highest_loa
                                             })
      end

      def icn_found
        render json:
          {
            "id": @user.icn,
            "type": 'user-mvi-icn',
            "data": {
              "attributes": {
                "icn": @user.icn
              }
            }
          }
      end

      def icn_not_found
        render json:
          {
            "id": 'not_found',
            "type": 'user-mvi-icn',
            "data": {
              "errors": {
                "icn": 'could not locate ICN'
              }
            }
          }
      end

      def highest_loa
        request.headers['x-va-level-of-assurance'].to_i == 3 ? 3 : 1
      end

      def check_required_headers
        raise Common::Exceptions::ParameterMissing, 'X-VA-SSN or X-VA-EDIPI' if missing_ssn_or_edipi
        raise Common::Exceptions::ParameterMissing, 'x-va-level-of-assurance' if missing_loa
        raise Common::Exceptions::ParameterMissing, 'x-va-user-email' if missing_email
      end

      def missing_ssn_or_edipi
        request.headers['x-va-ssn'].blank? && request.headers['x-va-edipi'].blank?
      end

      def missing_email
        request.headers['x-va-user-email'].blank?
      end

      def missing_loa
        request.headers['x-va-level-of-assurance'].blank?
      end
    end
  end
end
