# frozen_string_literal: true

module MyHealth
  module V1
    class VitalsController < MrController
      def index
        resource = client.list_vitals
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end
    end
  end
end
