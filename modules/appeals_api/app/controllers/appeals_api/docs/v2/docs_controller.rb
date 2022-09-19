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

  def hlr
    swagger = if Settings.vsp_environment == 'production'
                JSON.parse(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v2/swagger_hlr.json')))
              else
                JSON.parse(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v2/swagger_hlr_dev.json')))
              end
    render json: swagger
  end

  def nod
    swagger = if Settings.vsp_environment == 'production'
                JSON.parse(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v2/swagger_nod.json')))
              else
                JSON.parse(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v2/swagger_nod_dev.json')))
              end
    render json: swagger
  end
end
