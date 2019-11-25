# frozen_string_literal: true

module VbaDocuments
  module V1
    class SwaggerRoot
      include Swagger::Blocks
      swagger_root do
        key :swagger, '2.0'
        info do
          key :version, '1.0.0'
          key :title, 'Benefits Intake'
          key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'v1', 'description.md'))
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

        security_definition :apikey do
          key :type, :apiKey
          key :name, :apikey
          key :in, :header
        end

        key :schemes, ['https']
        key :host, 'api.va.gov'
        key :basePath, '/services/vba_documents/v1'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
