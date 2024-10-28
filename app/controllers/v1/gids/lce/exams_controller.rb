# frozen_string_literal: true

module V1
  module GIDS
    module Lce
      class ExamsController < GIDS::LceController
        def show
          render json: service.get_exam_details_v1(scrubbed_params)
        end
      end
    end
  end
end
