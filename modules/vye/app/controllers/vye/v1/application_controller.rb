# frozen_string_literal: true

class Vye::V1::ApplicationController < Vye::ApplicationController
  class FeatureDisabled < StandardError; end

  attr_reader :user_info

  before_action :verify_feature_enabled!
  before_action :load_user_info

  rescue_from Pundit::NotAuthorizedError, with: -> { head :forbidden }
  rescue_from FeatureDisabled, with: -> { head :bad_request }

  private

  def verify_feature_enabled!
    return true if Flipper.enabled?(:vye_request_allowed)

    raise FeatureDisabled
  end

  def load_user_info
    @user_info = Vye::UserInfo.find_and_update_icn(user: current_user)
  end
end
