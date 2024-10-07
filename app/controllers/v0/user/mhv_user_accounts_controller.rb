# frozen_string_literal: true

module V0
  module User
    class MHVUserAccountsController < ApplicationController
      service_tag 'identity'

      before_action :set_mhv_user_account, only: :show
      rescue_from MHV::UserAccount::Errors::UserAccountError, with: ->(e) { render_errors(e.message) }

      def show
        return render_errors('not_found', status: :not_found) if @mhv_user_account.blank?

        log_result('success')
        render json: MHVUserAccountSerializer.new(@mhv_user_account).serializable_hash, status: :ok
      end

      private

      def set_mhv_user_account
        @mhv_user_account = current_user.mhv_user_account
      end

      def render_errors(error_message, status: :unprocessable_entity)
        log_result('error', error_message:)

        errors = error_message.split(',').map { |m| { detail: m.strip } }
        render json: { errors: }, status:
      end

      def log_result(result, **payload)
        Rails.logger.info("[User][MHVUserAccountsController] #{action_name} #{result}", payload)
      end
    end
  end
end
