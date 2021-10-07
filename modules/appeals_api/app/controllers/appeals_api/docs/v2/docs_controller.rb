# frozen_string_literal: true

class AppealsApi::Docs::V2::DocsController < ApplicationController
  skip_before_action(:authenticate)

  def decision_reviews
    swagger = if Settings.vsp_environment == 'production'
                JSON.parse(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v2/swagger.json')))
              else
                JSON.parse(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v2/swagger_dev.json')))
              end
    render json: swagger
  end
end
