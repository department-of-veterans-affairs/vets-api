# frozen_string_literal: true

module VBADocuments
  module V2
    class SwaggerRoot
      include Swagger::Blocks
      VBA_TAG = ['VBA Documents'].freeze
      swagger_root do
        key :openapi, '3.0.0'
        info do
          key :version, '2.0.0'
          key :title, 'Benefits Intake'
          key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'v2', 'description.md'))
          contact do
            key :name, 'va.gov'
          end
        end

        tag do
          key :name, VBA_TAG
          key :description, 'VA Benefits document upload functionality'
        end

        server do
          key :url, 'https://dev-api.va.gov/'
          key :description, 'VA.gov API dev environment'
          variable :version do
            key :default, 'v2'
          end
        end

        key :basePath, '/services/vba_documents/v2'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
