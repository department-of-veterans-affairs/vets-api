# frozen_string_literal: true

require 'apps/client'

module V0
  class AppsController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate

    def index
      response = Apps::Client.new.get_all
      render json: response.body,
             status: response.status
    end

    def show
      response = Apps::Client.new(params[:id]).get_app
      render json: response.body,
             status: response.status
    end

    def scopes
      response = Apps::Client.new(params[:category]).get_scopes
      render json: response.body,
             status: response.status
    end
  end
end
