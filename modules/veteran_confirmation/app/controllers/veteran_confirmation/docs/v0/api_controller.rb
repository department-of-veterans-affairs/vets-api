# frozen_string_literal: true

module VeteranConfirmation
  module Docs
    module V0
      class ApiController < ApplicationController
        def status
          swagger = YAML.safe_load(File.read(VeteranConfirmation::Engine.root.join('VETERAN_CONFIRMATION.yml')))
          render json: swagger
        end
      end
    end
  end
end
