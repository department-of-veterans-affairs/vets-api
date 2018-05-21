# frozen_string_literal: true

module AppealsApi
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)

        def index
          swagger = YAML.safe_load(File.read(VBADocuments::Engine.root.join('README.yml')))
          render json: swagger
        end
      end
    end
  end
end
