# frozen_string_literal: true

module MyHealth
  module V1
    class VitalsController < MrController
      def index
        resource = client.list_vitals(params[:from], params[:to])
        render json: resource.to_json
      end
    end
  end
end
