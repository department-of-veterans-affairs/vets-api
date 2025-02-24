# frozen_string_literal: true

module VBADocuments
  module V1
    class SwaggerRoot
      include Swagger::Blocks
      VBA_TAG = ['VBA Documents'].freeze
      DESCRIPTION_FILE_NAME = Flipper.enabled?(:vba_documents_final_status_field) ? 'description_with_final_status.md' : 'description.md'
      swagger_root do
        key :openapi, '3.0.0'
        info do
          key :version, '1.0.0'
          key :title, 'Benefits Intake'
          key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'v1', DESCRIPTION_FILE_NAME))
          contact do
            key :name, 'va.gov'
          end
        end

        tag do
          key :name, VBA_TAG
          key :description, 'VA Benefits document upload functionality'
        end

        server do
          key :url, 'https://sandbox-api.va.gov/services/vba_documents/{version}'
          key :description, 'VA.gov API sandbox environment'
          variable :version do
            key :default, 'v1'
          end
        end

        server do
          key :url, 'https://api.va.gov/services/vba_documents/{version}'
          key :description, 'VA.gov API production environment'
          variable :version do
            key :default, 'v1'
          end
        end

        key :basePath, '/services/vba_documents/v1'
        key :consumes, ['application/json']
        key :produces, ['application/json']
      end
    end
  end
end
