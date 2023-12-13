# frozen_string_literal: true

class Vye::V1::UserInfosController < Vye::V1::ApplicationController
  # skip_before_action :authenticate

  def show
    render json: user_info,
           serializer: Vye::UserInfoSerializer,
           include: %i[awards pending_documents verifications]
  end

  private

  def load_user_info
    @user_info = Vye::UserInfo
                 .includes(:awards, :pending_documents, :verifications)
                 .find_and_update_icn(user: current_user)
  end
end
