# frozen_string_literal: true

require 'preneeds/service'

module Mobile
  module V0
    class CemeteriesController < ApplicationController
      def index
        resource = client.get_cemeteries

        render json: Mobile::V0::CemeteriesSerializer.new(resource)
      end

      def client
        @client ||= Preneeds::Service.new
      end
    end
  end
end
