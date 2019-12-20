# frozen_string_literal: true

module VeteranVerification
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)

        def history
          swagger = YAML.safe_load(service_history_file)
          render json: swagger
        end

        def rating
          swagger = YAML.safe_load(disability_rating_file)
          render json: swagger
        end

        def status
          swagger = YAML.safe_load(status_file)
          render json: swagger
        end

        def metadata
          swagger = YAML.safe_load( metadata_template )
          render json: swagger
        end

        private

        def metadata_template
          status_doc = YAML.safe_load(status_file)['paths']['/status']
          disability_rating_doc = YAML.safe_load(disability_rating_file)['paths']['/disability_rating']
          service_history_doc = YAML.safe_load(service_history_file)['paths']['/service_history']
          metadata_doc = YAML.safe_load(metadata_file)
          metadata_doc['paths']['/status'] = status_doc
          metadata_doc['paths']['/disability_rating'] = disability_rating_doc
          metadata_doc['paths']['/service_history'] = service_history_doc

          metadata_doc.to_yaml
        end

        def metadata_file
          File.read(VeteranVerification::Engine.root.join('METADATA.yml'))
        end

        def disability_rating_file
          File.read(VeteranVerification::Engine.root.join('DISABILITY_RATING.yml'))
        end

        def status_file
          File.read(VeteranVerification::Engine.root.join('VETERAN_CONFIRMATION.yml'))
        end

        def service_history_file
          File.read(VeteranVerification::Engine.root.join('SERVICE_HISTORY.yml'))
        end
      end
    end
  end
end
