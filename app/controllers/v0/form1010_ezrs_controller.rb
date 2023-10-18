# frozen_string_literal: true

module V0
  class Form1010EzrsController < ApplicationController
    skip_before_action :authenticate, only: %i[create]
    before_action :load_user, only: %i[create]

    def create
      begin
        result = Form1010Ezr::Service.new(@current_user).submit_form(params[:form])
      rescue HCA::SOAPParser::ValidationError
        raise Common::Exceptions::BackendServiceException.new('1010EZR422', status: 422)
      end

      clear_saved_form('1010ezr')

      render(json: result)
    end
  end
end
