# frozen_string_literal: true

module V0
  class MHVOptInFlagsController < ApplicationController
    def show
      opt_in_flag = MHVOptInFlag.find_by(user_account_id: current_user.user_account, feature: params[:feature])
      raise Common::Exceptions::RecordNotFound, message: 'Record not found' if opt_in_flag.nil?

      render json: { mhv_opt_in_flag: { user_account_id: opt_in_flag.user_account_id, feature: opt_in_flag.feature } }
    rescue => e
      render json: { errors: e.message }, status: :not_found
    end

    def create
      feature = params[:feature]
      unless MHVOptInFlag::FEATURES.include?(feature)
        raise MHVOptInFlagFeatureNotValid.new message: 'Feature param is not valid'
      end

      status = :ok
      opt_in_flag = MHVOptInFlag.find_or_create_by(user_account: current_user.user_account,
                                                   feature:) do |_mhv_opt_in_flag|
        status = :created
      end
      render json: { mhv_opt_in_flag: { user_account_id: opt_in_flag.user_account_id, feature: opt_in_flag.feature } },
             status:
    rescue MHVOptInFlagFeatureNotValid => e
      render json: { errors: e }, status: :bad_request
    rescue
      render json: { errors: 'Internal Server Error' }, status: :internal_server_error
    end

    class MHVOptInFlagFeatureNotValid < StandardError; end
  end
end
