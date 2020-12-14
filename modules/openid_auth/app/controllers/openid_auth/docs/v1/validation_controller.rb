# frozen_string_literal: true

module OpenidAuth
  module Docs
    module V1
      class ValidationController < ApplicationController
        skip_before_action(:authenticate)

        def index
          swagger = YAML.safe_load(File.read(OpenidAuth::Engine.root.join('README.yml')))
          render json: swagger
        end
      end
    end
  end
end
