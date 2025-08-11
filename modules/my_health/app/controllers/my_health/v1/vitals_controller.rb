# frozen_string_literal: true

module MyHealth
  module V1
    class VitalsController < MRController
      def index
        render_resource client.list_vitals(params[:from], params[:to])
      end
    end
  end
end
