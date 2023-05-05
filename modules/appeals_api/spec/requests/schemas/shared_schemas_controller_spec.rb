# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::Schemas::SharedSchemasController, type: :request do
  include FixtureHelpers

  def base_path(appeal_type_segment, schema_type)
    "/services/appeals/#{appeal_type_segment}/v0/schemas/#{schema_type}"
  end

  shared_examples 'successful schema request' do |schema_type, response_body_content|
    appeal_type_segments = %w[notice-of-disagreements higher-level-reviews supplemental-claims]

    appeal_type_segments.each do |appeal_type|
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
      appeal_type_segments = %w[notice-of-disagreements higher-level-reviews supplemental-claims]
      appeal_forms = %w[10182 200996 200995]

      appeal_type_segments.each.with_index do |appeal_type, i|
        it 'raises an error with form number in meta' do
          get base_path appeal_type, :bananas

          error = JSON.parse(response.body)['errors'].first

          expect(response.status).to eq(404)
          expect(error['detail']).to include 'request parameter is invalid'
          expect(error['source']['parameter']).to include 'bananas'
          expect(error['meta']).to be_a Hash
          expect(error['meta']['available_options']).to include appeal_forms[i]
        end
      end
    end
  end
end
