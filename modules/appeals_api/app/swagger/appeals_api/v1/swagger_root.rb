# frozen_string_literal: true

module AppealsApi::V1::SwaggerRoot
  include Swagger::Blocks

  read_file = ->(path) { File.read(AppealsApi::Engine.root.join(*path)) }
  read_file_from_same_dir = ->(filename) { read_file.call(['app', 'swagger', 'appeals_api', 'v1', filename]) }

  swagger_root do
    key :openapi, '3.0.0'
    info do
      key :title, 'Decision Reviews'
      key :version, '1.0.0'
      key :description, read_file_from_same_dir['api_description.md']
      key :termsOfService, 'https://developer.va.gov/terms-of-service'
      contact do
        key :name, 'VA API Benefits Team'
      end
    end

    url = ->(prefix = '') { "https://#{prefix}api.va.gov/services/appeals/{version}/decision_reviews" }

    server description: 'VA.gov API sandbox environment', url: url['sandbox-'] do
      variable(:version) { key :default, 'v1' }
    end

    server description: 'VA.gov API production environment', url: url[''] do
      variable(:version) { key :default, 'v1' }
    end

    key :basePath, '/services/appeals/v1'
    key :consumes, ['application/json']
    key :produces, ['application/json']

    security do
      key :type, :apiKey
      key :name, :apiKey
      key :in, :header
    end
  end
end
