# frozen_string_literal: true

class AppealsApi::Docs::V1::DocsController < ApplicationController
  skip_before_action(:authenticate)

  SWAGGERED_CLASSES = [
    AppealsApi::V1::HigherLevelReviewsControllerSwagger,
    AppealsApi::V1::NoticeOfDisagreementsControllerSwagger,
    AppealsApi::V1::SwaggerRoot
  ].freeze

  def decision_reviews
    render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
  end
end
