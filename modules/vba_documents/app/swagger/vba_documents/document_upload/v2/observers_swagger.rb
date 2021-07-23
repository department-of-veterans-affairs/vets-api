# frozen_string_literal: true

module VBADocuments
  module DocumentUpload
    module V2
      class ObserversSwagger
        include Swagger::Blocks
        EXAMPLE_PATH = VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'v2', 'observer_example.json')
        swagger_component do
          schema :Observers do
            key :type, :object
            key :in, :formData
            key :example, JSON.parse(File.read(EXAMPLE_PATH))
            property :subscriptions do
              key :description, 'An optional object that can be passed for notifications'
              key :example, JSON.parse(File.read(EXAMPLE_PATH))
              key :type, :array
              items do
                property :event do
                  key :type, :string
                  key :example, 'gov.va.developer.benefits-intake.status_change'
                  key :description, 'The event subscribing to'
                end
                property :urls do
                  key :type, :array
                  key :description, 'The URL of the server(s) receiving the notification'
                  items do
                    key :type, :string
                    key :example, '"https://i/am/listening"'

                    key :type, :string
                    key :example, '"https://i/am/also/listening"'
                  end
                end
              end
              key :minItems, 1
              key :maxItems, 1000
            end
          end
        end
      end
    end
  end
end
