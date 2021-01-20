# frozen_string_literal: true

module VBADocuments
  module V1
    module Responses
      module InternalServerError
        # rubocop:disable Metrics/MethodLength
        def self.extended(base)
          base.response 500 do
            key :description, 'Internal Server Error'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :title do
                  key :description, 'Human readable title description.'
                  key :type, :string
                  key :example, 'Internal Server Error'
                end
                property :detail do
                  key :description, 'Human readable error detail. Only present if status = "error"'
                  key :type, :string
                  key :example, 'Internal Server Error'
                end
                property :code do
                  key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'status_code_description.md'))
                  key :type, :string
                  key :example, 500
                end
                property :status do
                  key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'status_code_description.md'))
                  key :type, :string
                  key :example, 500
                end
              end
            end
          end
          # rubocop:enable Metrics/MethodLength
        end
      end
    end
  end
end
