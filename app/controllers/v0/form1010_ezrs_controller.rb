# frozen_string_literal: true

module V0
  class Form1010EzrsController < ApplicationController
    def create
      # As of 10/20/23, unauthenticated users cannot submit an EZR
      raise Common::Exceptions::BackendServiceException, '1010EZR_401' if @current_user.nil?

      begin
        parsed_form = parse_form(params[:form])
        result = Form1010Ezr::Service.new(@current_user).submit_form(parsed_form)
      rescue
        raise Common::Exceptions::BackendServiceException, '1010EZR_400'
      end

      clear_saved_form('1010ezr')

      render(json: result)
    end

    private

    def parse_form(form)
      JSON.parse(form)
    end
  end
end
