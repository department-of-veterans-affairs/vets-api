# frozen_string_literal: true

module V0
  module Preneeds
    class CemeteriesController < PreneedsController
      def index
        resource = client.get_cemeteries
        render json: CemeterySerializer.new(resource.records)
      end
    end
  end
end
