# frozen_string_literal: true

class FlipperController < ApplicationController
  service_tag 'feature-flag'
  skip_before_action :authenticate

  def login
    # Swallow auth token and redirect to /flipper/features with a param for allowing authentication
    redirect_to '/flipper/features?oauth=true'
  end

  def logout
    cookies.delete :api_session
    redirect_to '/flipper/features'
  end
end
