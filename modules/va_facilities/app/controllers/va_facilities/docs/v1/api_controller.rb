# frozen_string_literal: true

module VaFacilities
  module Docs
    module V1
      class ApiController < ApplicationController
        skip_before_action(:authenticate)

        def index
          swagger = YAML.safe_load(File.read(VaFacilities::Engine.root.join('README.v1.yml')))
          render json: swagger
        end
      end
    end
  end
end
