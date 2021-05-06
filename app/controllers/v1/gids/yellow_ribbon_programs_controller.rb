# frozen_string_literal: true

module V1
  module GIDS
    class YellowRibbonProgramsController < GIDSController
      def index
        render json: service.get_yellow_ribbon_programs_v1(scrubbed_params)
      end
    end
  end
end
