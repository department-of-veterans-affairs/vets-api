# frozen_string_literal: true

module ClaimsApi
  class ErrorModelSwagger
    include Swagger::Blocks
  
    swagger_schema :ErrorModel do
      key :description, 'Errors with some details for the given request'
      
      key :required, [:status, :details]
      property :status do
        key :type, :integer
        key :format, :int32
      end
    
      property :details do
        key :type, :string
      end
    end
  end
end