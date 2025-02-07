# frozen_string_literal: true

module V1
  module GIDS
    module LCPE
      class ExamsController < GIDS::LCPEController
        def index
          exams = service.get_exams_v1(scrubbed_params)
          set_etag(exams.version) if versioning_required?
          render json: exams
        end

        def show
          render json: service.get_exam_details_v1(scrubbed_params)
        end

        private

        # versioning currently disabled for exams#show
        # exclude :version (and not :id) from params
        def versioning_required?
          scrubbed_params.except(:version).blank?
        end
      end
    end
  end
end
