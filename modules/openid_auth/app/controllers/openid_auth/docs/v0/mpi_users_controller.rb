# frozen_string_literal: true

module OpenidAuth
  module Docs
    module V0
      class MPIUsersController < ApplicationController
        skip_before_action(:authenticate)

        def index
          swagger = YAML.safe_load(File.read(OpenidAuth::Engine.root.join('MVI_README.yml')))
          render json: swagger
        end
      end
    end
  end
end
