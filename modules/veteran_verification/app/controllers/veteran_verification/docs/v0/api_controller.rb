# frozen_string_literal: true

module VeteranVerification
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)

        def history
          swagger = service_history_yaml
          render json: swagger
        end

        def rating
          swagger = disability_rating_yaml
          render json: swagger
        end

        def status
          swagger = status_yaml
          render json: swagger
        end

        def veteran_verification
          swagger = verification_template
          render json: swagger
        end

        private

        def verification_template
          status_doc = status_yaml['paths']['/status']
          status_schema = status_yaml['components']['schemas']

          disability_rating_doc = disability_rating_yaml['paths']['/disability_rating']
          disability_rating_schema = disability_rating_yaml['components']['schemas']

          service_history_doc = service_history_yaml['paths']['/service_history']
          service_history_schema = service_history_yaml['components']['schemas']

          verification_doc = verification_yaml

          verification_doc['paths']['/status'] = status_doc
          verification_doc['paths']['/disability_rating'] = disability_rating_doc
          verification_doc['paths']['/service_history'] = service_history_doc

          schemas = {}.merge(status_schema).merge(disability_rating_schema).merge(service_history_schema)

          verification_doc['components']['schemas'] = schemas

          verification_doc
        end

        def verification_yaml
          @verification_yaml ||= YAML.safe_load(File.read(VeteranVerification::Engine.root.join('VETERAN_VERIFICATION.yml')))
        end

        def disability_rating_yaml
          @disability_yaml ||= YAML.safe_load(File.read(VeteranVerification::Engine.root.join('DISABILITY_RATING.yml')))
        end

        def status_yaml
          @status_yaml ||= YAML.safe_load(File.read(VeteranVerification::Engine.root.join('VETERAN_CONFIRMATION.yml')))
        end

        def service_history_yaml
          @service_yaml ||= YAML.safe_load(File.read(VeteranVerification::Engine.root.join('SERVICE_HISTORY.yml')))
        end
      end
    end
  end
end
