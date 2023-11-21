# frozen_string_literal: true

require 'forms/client'

module V0
  class FormsController < ApplicationController
    include ActionView::Helpers::SanitizeHelper
    service_tag 'find-a-form'

    skip_before_action :authenticate

    def index
      response = Forms::Client.new(params[:query]).get_all
      render json: response.body,
             status: response.status
    end
  end
end
