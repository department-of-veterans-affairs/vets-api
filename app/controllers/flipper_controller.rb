# frozen_string_literal: true

class FlipperController < ApplicationController
  skip_before_action :authenticate
  def logout
    cookies.delete :api_session
    redirect_to '/flipper/features'
  end
end
