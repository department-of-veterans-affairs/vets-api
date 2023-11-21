# frozen_string_literal: true

class Swagger::V1::Requests::IncomeLimits
  include Swagger::Blocks

  swagger_path '/income_limits/v1/limitsByZipCode/{zip}/{year}/{dependents}' do
    operation :get do
      key :description, 'Gets the income limits'
      key :operationId, 'getlimitsByZipCode'
      key :tags, %w[income_limits]

      parameter do
        key :name, :zip
        key :in, :path
        key :description, 'Zip Code'
        key :minLength, 5
        key :maxLength, 5
        key :required, true
        key :type, :integer
        key :format, :int64
      end

      parameter do
        key :name, :year
        key :in, :path
        key :description, 'Year'
        key :minimum, 1970
        key :maximum, 2999
        key :required, true
        key :type, :integer
        key :format, :int64
      end

      parameter do
        key :name, :dependents
        key :in, :path
        key :description, 'Dependents'
        key :required, true
        key :type, :integer
        key :format, :int64
      end

      response 200 do
        key :description, 'response'
        schema do
          key :$ref, :IncomeLimitThresholds
        end
      end
      response 422 do
        key :description, 'unprocessable_entity'
      end
    end
  end

  swagger_path '/income_limits/v1/validateZipCode/{zip}' do
    operation :get do
      key :description, 'Validate Zip Code'
      key :operationId, 'getIncomeLimits'
      key :tags, %w[income_limits]

      parameter do
        key :name, :zip
        key :in, :path
        key :description, 'Zip Code'
        key :minLength, 5
        key :maxLength, 5
        key :required, true
        key :type, :integer
        key :format, :int64
      end

      response 200 do
        key :description, 'response'
        schema do
          key :$ref, :ZipCodeIsValid
        end
      end
    end
  end
end
