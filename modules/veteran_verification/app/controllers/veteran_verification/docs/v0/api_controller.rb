# frozen_string_literal: true

module VeteranVerification
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)

        def history
          swagger = YAML.safe_load(File.read(VeteranVerification::Engine.root.join('SERVICE_HISTORY.yml')))
          render json: swagger
        end

        def rating
          swagger = YAML.safe_load(File.read(VeteranVerification::Engine.root.join('DISABILITY_RATING.yml')))
          render json: swagger
        end

        def status
          swagger = YAML.safe_load(File.read(VeteranVerification::Engine.root.join('VETERAN_CONFIRMATION.yml')))
          render json: swagger
        end
      end
    end
  end
end
