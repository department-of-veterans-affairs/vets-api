# frozen_string_literal: true

module VeteranVerification
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)

        def veteran_verification
          swagger = verification_yaml
          render json: swagger
        end

        private

        def verification_yaml
          @verification_yaml ||= YAML.safe_load(
            File.read(VeteranVerification::Engine.root.join('VETERAN_VERIFICATION_V0.yml'))
          )
        end
      end
    end
  end
end
