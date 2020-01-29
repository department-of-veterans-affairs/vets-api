# frozen_string_literal: true

class AppealsApi::Docs::V1::DocsController < ApplicationController
  skip_before_action(:authenticate)

  def decision_reviews
    swagger = YAML.safe_load(File.read(AppealsApi::Engine.root.join('app/docs/v0/vaos.yaml')))
    render json: swagger
  end
end
