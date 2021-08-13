# frozen_string_literal: true

class AppealsApi::Docs::V2::DocsController < ApplicationController
  skip_before_action(:authenticate)

  SWAGGERED_CLASSES = [
    AppealsApi::V2::HigherLevelReviewsControllerSwagger,
    AppealsApi::V1::NoticeOfDisagreementsControllerSwagger,
    AppealsApi::V1::Schemas::NoticeOfDisagreements,
    AppealsApi::V2::Schemas::HigherLevelReviews,
    AppealsApi::V2::SecuritySchemeSwagger,
    AppealsApi::V2::SwaggerRoot
  ].freeze

  def decision_reviews
    render json: decision_reviews_swagger_json
  end

  def decision_reviews_beta
    swagger = JSON.parse(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v2/swagger.json')))
    render json: swagger
  end

  private

  def decision_reviews_swagger_json
    Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
                   .deep_merge(
                     AppealsApi::V2::Schemas::HigherLevelReviews.hlr_legacy_schemas
                   ).deep_merge(
                     AppealsApi::V1::Schemas::NoticeOfDisagreements.nod_json_schemas
                   )
  end
end
