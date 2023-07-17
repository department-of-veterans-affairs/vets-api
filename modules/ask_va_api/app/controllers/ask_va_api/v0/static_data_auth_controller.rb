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
        render json: data, status: :ok
      end
    end
  end
end
