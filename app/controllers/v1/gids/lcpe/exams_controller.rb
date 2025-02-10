# frozen_string_literal: true

module V1
  module GIDS
    module LCPE
      class ExamsController < GIDS::LCPEController
        # versioning currently disabled for exams#show, exclude :version (and not :id)
        VERSIONING_PARAMS = %i[version].freeze

        def index
          exams = service.get_exams_v1(scrubbed_params)
          set_etag(exams.version) unless bypass_versioning?
          render json: exams
        end

        def show
          render json: service.get_exam_details_v1(scrubbed_params)
        end
      end
    end
  end
end
