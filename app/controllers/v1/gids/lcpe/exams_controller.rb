# frozen_string_literal: true

module V1
  module GIDS
    module LCPE
      class ExamsController < GIDS::LCPEController
        def index
          render json: service.get_exams_v1(scrubbed_params)
        end

        def show
          render json: service.get_exam_details_v1(scrubbed_params)
        end
      end
    end
  end
end
