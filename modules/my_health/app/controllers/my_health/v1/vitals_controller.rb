# frozen_string_literal: true

module MyHealth
  module V1
    class VitalsController < MrController
      def index
        resource = if params[:from] && params[:to]
                     client.list_vitals(params[:from], params[:to])
                   else
                     client.list_vitals
                   end

        render json: resource.to_json
      end
    end
  end
end
