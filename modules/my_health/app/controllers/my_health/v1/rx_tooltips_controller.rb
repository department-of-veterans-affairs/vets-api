module MyHealth
  module V1
    class RxTooltipsController < MyHealth::RxController
      before_action :set_user_account, only: [:index, :create, :update]

      def index
        tooltips = @user_account.tooltips
        render json: tooltips
      end

      def create
        ##
      end

      def update
        ##
      end

      private

      def set_user_account
        @user_account = UserAccount.find_by(uuid: current_user.user_account_uuid)
        render json: { error: 'User account not found' }, status: :not_found unless @user_account
      end
    end
  end
end