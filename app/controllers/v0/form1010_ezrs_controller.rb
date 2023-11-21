# frozen_string_literal: true

require 'form1010_ezr/service'

module V0
  class Form1010EzrsController < ApplicationController
    def create
      parsed_form = parse_form(params[:form])

      result = Form1010Ezr::Service.new(@current_user).submit_form(parsed_form)

      clear_saved_form('10-10EZR')

      render(json: result)
    end

    private

    def parse_form(form)
      JSON.parse(form)
    end
  end
end
