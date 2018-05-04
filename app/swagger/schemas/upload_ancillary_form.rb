# frozen_string_literal: true

module Swagger
  module Schemas
    class UploadAncillaryForm
      include Swagger::Blocks

      swagger_schema :UploadAncillaryForm do
        key :required, [:data]

        property :data, type: :object do
          property :attributes, type: :object do
            key :required, %i[upload_guid]
            property :upload_guid, type: :integer, example: 7834308293
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_disability_compensation_form_upload_ancillary_form' #this doesn't exist yet
        end
      end
    end
  end
end

