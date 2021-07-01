# frozen_string_literal: true

class AppealsApi::Docs::V1::DocsController < ApplicationController
  skip_before_action(:authenticate)

  SWAGGERED_CLASSES = [
    AppealsApi::V1::HigherLevelReviewsControllerSwagger,
    AppealsApi::V1::NoticeOfDisagreementsControllerSwagger,
    AppealsApi::V1::Schemas::NoticeOfDisagreements,
    AppealsApi::V1::Schemas::HigherLevelReviews,
    AppealsApi::V1::SecuritySchemeSwagger,
    AppealsApi::V1::SwaggerRoot
  ].freeze

  def decision_reviews
    render json: decision_reviews_swagger_json
  end

  private

  def decision_reviews_swagger_json
    Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
                   .deep_merge(
                     AppealsApi::V1::Schemas::HigherLevelReviews.hlr_legacy_schemas
                   ).deep_merge(
                     AppealsApi::V1::Schemas::NoticeOfDisagreements.nod_json_schemas
                   )
  end
end
