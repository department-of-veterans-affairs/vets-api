# frozen_string_literal: true

module VbaDocuments
  module V0
    class SwaggerRoot
      include Swagger::Blocks
      swagger_root do
        key :openapi, '3.0.0'
        info do
          key :version, '0.0.0'
          key :title, 'Benefits Intake'
          key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'v0', 'description.md'))
          contact do
            key :name, 'va.gov'
          end
        end

        tag do
          key :name, 'document_uploads'
          key :description, 'VA Benefits document upload functionality'
          externalDocs do
            key :description, 'Find more info here'
            key :url, 'https://developer.va.gov'
          end
        end

        server do
          key :url, 'https://dev-api.va.gov/services/vba_documents/{version}'
          key :description, 'VA.gov API development environment'
          variable :version do
            key :default, 'v0'
          end
        end

        server do
          key :url, 'https://staging-api.va.gov/services/vba_documents/{version}'
          key :description, 'VA.gov API staging environment'
          variable :version do
            key :default, 'v0'
          end
        end

        server do
          key :url, 'https://api.va.gov/services/vba_documents/{version}'
          key :description, 'VA.gov API production environment'
          variable :version do
            key :default, 'v0'
          end
        end

        key :basePath, '/services/vba_documents/v0'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
