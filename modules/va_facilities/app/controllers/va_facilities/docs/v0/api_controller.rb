# frozen_string_literal: true

module VAFacilities
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)

        def index
          swagger = YAML.safe_load(File.read(VAFacilities::Engine.root.join('README.yml')))
          render json: swagger
        end
      end
    end
  end
end
