# frozen_string_literal: true

module V0
  class HomepageBannerController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate

    def index
      homepage_banner = HomepageBanner::Client.new().get_homepage_banner
      render json: homepage_banner
    end
  end
end
