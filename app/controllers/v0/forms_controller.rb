# frozen_string_literal: true

module V0
  class FormsController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate

    def index
      response = Forms::Client.new(params[:query]).get_all
      render json: response.body,
             status: response.status
    end
  end
end
