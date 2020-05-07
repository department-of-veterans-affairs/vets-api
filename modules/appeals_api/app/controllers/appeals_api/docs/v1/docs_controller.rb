# frozen_string_literal: true

class AppealsApi::Docs::V1::DocsController < ApplicationController
  skip_before_action(:authenticate)

  SWAGGER = Swagger::Blocks.build_root_json(
    [
      AppealsApi::V1::SwaggerRoot,
      AppealsApi::V1::HigherLevelReviewsControllerSwagger,
      AppealsApi::V1::ContestableIssuesControllerSwagger
    ]
  ).freeze

  def decision_reviews
    render json: SWAGGER
  end
end
