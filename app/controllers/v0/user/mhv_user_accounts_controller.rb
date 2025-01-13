# frozen_string_literal: true

module V0
  module User
    class MHVUserAccountsController < ApplicationController
      service_tag 'identity'
      rescue_from MHV::UserAccount::Errors::UserAccountError, with: :render_mhv_account_errors

      def show
        authorize MHVUserAccount
        mhv_user_account = MHV::UserAccount::Creator.new(user_verification: current_user.user_verification,
                                                         break_cache: true).perform

        return render_mhv_account_errors('not_found', status: :not_found) if mhv_user_account.blank?

        log_result('success')
        render json: MHVUserAccountSerializer.new(mhv_user_account).serializable_hash, status: :ok
      end

      private

      def render_mhv_account_errors(exception)
        errors = exception.as_json

        log_result('error', errors:)
        render json: { errors: }, status: :unprocessable_entity
      end

      def log_result(result, **payload)
        Rails.logger.info("[User][MHVUserAccountsController] #{action_name} #{result}", payload)
      end
    end
  end
end
