# frozen_string_literal: true

require 'rails_helper'

# The other scenarios are about a request-derived schema path to a valid schema.
# Within that, the scenarios of 1) including non-JSON body, 2) JSON body that
# does not pass schema, 3) and happy path are all tested in actual request specs
# currently. Also, these scenarios are onerous to test here.
describe ClaimsApi::V2::PowerOfAttorneyRequests::JsonValidation, type: :controller do
  controller(ActionController::API) do
    include ClaimsApi::V2::PowerOfAttorneyRequests::JsonValidation

    before_action(
      -> { validate_json!(schema_path: 'missing.json') },
      only: :missing
    )

    before_action(
      -> { validate_json!(schema_path: 'invalid.json') },
      only: :invalid
    )

    def missing
      header :no_content
    end

    def invalid
      header :no_content
    end
  end

  before do
    allow(Settings).to(
      receive(:claims_api).and_return(
        OpenStruct.new(schema_dir: 'spec/fixtures/json_validation_schemas')
      )
    )

    routes.draw do
      post 'missing' => 'anonymous#missing', format: :json
      post 'invalid' => 'anonymous#invalid', format: :json
    end
  end

  describe 'when caller passes non existent schema' do
    it 'raises SchemaLoadError' do
      expect { post 'missing', params: {}, as: :json }.to(
        raise_error(described_class::SchemaLoadError, /missing/)
      )
    end
  end

  describe 'when caller passes invalid schema' do
    it 'raises SchemaLoadError' do
      expect { post 'invalid', params: {}, as: :json }.to(
        raise_error(described_class::SchemaLoadError, /invalid/)
      )
    end
  end
end
