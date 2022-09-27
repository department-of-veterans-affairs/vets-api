# frozen_string_literal: true

class AppealsApi::Docs::V2::DocsController < ApplicationController
  skip_before_action(:authenticate)

  def decision_reviews
    filename = Settings.vsp_environment == 'production' ? 'swagger.json' : 'swagger_dev.json'
    file = File.read AppealsApi::Engine.root.join("app/swagger/appeals_api/v2/#{filename}")
    render json: JSON.parse(file)
  end

  def hlr
    render json: JSON.parse(swagger_file('hlr'))
  end

  def nod
    render json: JSON.parse(swagger_file('nod'))
  end

  def sc
    render json: JSON.parse(swagger_file('sc'))
  end

  def ci
    render json: JSON.parse(swagger_file('contestable_issues'))
  end

  def la
    render json: JSON.parse(swagger_file('legacy_appeals'))
  end

  private

  def swagger_file(stub, version: 'v2')
    filename = Settings.vsp_environment == 'production' ? "swagger_#{stub}.json" : "swagger_#{stub}_dev.json"
    File.read AppealsApi::Engine.root.join("app/swagger/appeals_api/#{version}/#{filename}")
  end
end
