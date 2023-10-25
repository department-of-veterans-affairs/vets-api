# frozen_string_literal: true

module V0
  class Form1010EzrsController < ApplicationController
    def create
      parsed_form = parse_form(params[:form])

      begin
        Form1010Ezr::Service.new(@current_user).submit_form(parsed_form)
      rescue HCA::SOAPParser::ValidationError
        raise Common::Exceptions::BackendServiceException.new('HCA422', status: 422)
      end

      clear_saved_form('10-10EZR')

      render(json: result)
    end

    private

    def parse_form(form)
      JSON.parse(form)
    end
  end
end
