# frozen_string_literal: true

module AskVAApi
  module V0
    class StaticDataAuthController < ApplicationController
      def index
        data = {
          Ruchi: { 'data-info' => 'ruchi.shah@thoughtworks.com' },
          Eddie: { 'data-info' => 'eddie.otero@oddball.io' },
          Jacob: { 'data-info' => 'jacob@docme360.com' },
          Joe: { 'data-info' => 'joe.hall@thoughtworks.com' },
          Khoa: { 'data-info' => 'khoa.nguyen@oddball.io' }
        }
        if current_user&.email&.match?(/vets\.gov\.user\+228/) == true
          render json: data, status: :ok and return
        else
          render json: { error: 'You do not have access to this resource.' }, status: '403' and return
        end
      rescue => e
        service_exception_handler(e)
      end
    end
  end
end
