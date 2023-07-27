# frozen_string_literal: true

module AskVAApi
  module V0
    class StaticDataController < ApplicationController
      skip_before_action :authenticate

      def index
        data = {
          Emily: { 'data-info' => 'emily@oddball.io' },
          Eddie: { 'data-info' => 'eddie.otero@oddball.io' },
          Jacob: { 'data-info' => 'jacob@docme360.com' },
          Joe: { 'data-info' => 'joe.hall@thoughtworks.com' },
          Khoa: { 'data-info' => 'khoa.nguyen@oddball.io' }
        }
        render json: data, status: :ok
      rescue => e
        service_exception_handler(e)
      end
    end
  end
end
