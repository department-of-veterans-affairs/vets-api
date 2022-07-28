# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::Schemas::SharedSchemasController, type: :request do
  include FixtureHelpers

  def base_path(appeal_type, schema_type)
    "/services/appeals/#{appeal_type}/v2/schemas/#{schema_type}"
  end

  shared_examples 'successful schema request' do |schema_type, response_body_content|
    appeal_types = %w[notice_of_disagreements higher_level_reviews supplemental_claims]

    appeal_types.each do |appeal_type|
      it "renders the #{schema_type} schema" do
        get base_path appeal_type, schema_type

        expect(response.status).to eq(200)

        response_body_content.each do |content_string|
          expect(response.body).to include content_string
        end
      end
    end
  end

  describe '#show' do
    describe "schema type 'non_blank_string'" do
      it_behaves_like 'successful schema request', 'non_blank_string', %w[nonBlankString]
    end

    describe "schema type 'address'" do
      it_behaves_like 'successful schema request', 'address', %w[address addressLine1]
    end

    describe "schema type 'phone'" do
      it_behaves_like 'successful schema request', 'phone', %w[phone areaCode]
    end

    describe "schema type 'timezone'" do
      it_behaves_like 'successful schema request', 'timezone', ['timezone', 'Abu Dhabi', 'Zurich']
    end

    context 'when unacceptable schema type provided' do
      appeal_types = %w[notice_of_disagreements higher_level_reviews supplemental_claims]

      appeal_types.each do |appeal_type|
        it 'raises an error' do
          get base_path appeal_type, :bananas

          error = JSON.parse(response.body)

          expect(response.status).to eq(404)
          expect(error['detail']).to include 'request parameter is invalid'
          expect(error['source']['parameter']).to include 'bananas'
          expect(error['meta']).to be_a Array
        end
      end
    end
  end
end
