# frozen_string_literal: true

module AppealsApi::V2::SwaggerRoot
  include Swagger::Blocks

  read_file = ->(path) { File.read(AppealsApi::Engine.root.join(*path)) }
  read_file_from_same_dir = ->(filename) { read_file.call(['app', 'swagger', 'appeals_api', 'v2', filename]) }

  swagger_root do
    key :openapi, '3.0.0'
    info do
      key :title, 'Decision Reviews'
      key :version, '2.0.0'
      key :description, read_file_from_same_dir['api_description.md']
      key :termsOfService, 'https://developer.va.gov/terms-of-service'
      contact do
        key :name, 'VA API Benefits Team'
      end
    end

    url = ->(prefix = '') { "https://#{prefix}api.va.gov/services/appeals/{version}/decision_reviews" }

    server description: 'VA.gov API sandbox environment', url: url['sandbox-'] do
      variable(:version) { key :default, 'v2' }
    end

    server description: 'VA.gov API production environment', url: url[''] do
      variable(:version) { key :default, 'v2' }
    end

    key :basePath, '/services/appeals/v2'
    key :consumes, ['application/json']
    key :produces, ['application/json']
  end
end
