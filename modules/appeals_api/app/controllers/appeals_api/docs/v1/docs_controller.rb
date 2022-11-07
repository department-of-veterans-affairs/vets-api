# frozen_string_literal: true

class AppealsApi::Docs::V1::DocsController < ApplicationController
  skip_before_action(:authenticate)

  SWAGGERED_DECISION_REVIEWS_CLASSES = [
    AppealsApi::V1::NoticeOfDisagreementsControllerSwagger,
    AppealsApi::V1::Schemas::NoticeOfDisagreements,
    AppealsApi::V1::SecuritySchemeSwagger,
    AppealsApi::V1::SwaggerRoot
  ].freeze

  def decision_reviews
    render json: decision_reviews_swagger_json
  end

  def appeals_status
    swagger = YAML.safe_load(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v1/appeals_status.yml')))
    render json: swagger
  end

  private

  def decision_reviews_swagger_json
    Swagger::Blocks.build_root_json(SWAGGERED_DECISION_REVIEWS_CLASSES)
                   .deep_merge(
                     AppealsApi::V1::Schemas::NoticeOfDisagreements.nod_json_schemas
                   )
  end
end
