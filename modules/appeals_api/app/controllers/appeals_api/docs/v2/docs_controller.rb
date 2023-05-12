# frozen_string_literal: true

class AppealsApi::Docs::V2::DocsController < ApplicationController
  skip_before_action(:authenticate)

  def decision_reviews
    render json: JSON.parse(swagger_file('decision_reviews', version: 'v2'))
  end

  def hlr
    render json: JSON.parse(swagger_file('higher_level_reviews'))
  end

  def nod
    render json: JSON.parse(swagger_file('notice_of_disagreements'))
  end

  def sc
    render json: JSON.parse(swagger_file('supplemental_claims'))
  end

  def ai
    render json: JSON.parse(swagger_file('appealable_issues'))
  end

  def la
    render json: JSON.parse(swagger_file('legacy_appeals'))
  end

  private

  def swagger_file(api_name, version: 'v0')
    filename = Settings.vsp_environment == 'production' ? 'swagger.json' : 'swagger_dev.json'
    File.read AppealsApi::Engine.root.join("app/swagger/#{api_name}/#{version}/#{filename}")
  end
end
