# frozen_string_literal: true

module V0
  class Form1010EzrsController < ApplicationController
    skip_before_action :authenticate, only: %i[create]
    before_action :load_user, only: %i[create]

    def create
      raise Common::Exceptions::BackendServiceException, '1010EZR_401' if @current_user.nil?

      begin
        result = Form1010Ezr::Service.new(@current_user).submit_form(params[:form])
      rescue
        raise Common::Exceptions::BackendServiceException, '1010EZR_400'
      end

      clear_saved_form('1010ezr')

      render(json: result)
    end
  end
end
