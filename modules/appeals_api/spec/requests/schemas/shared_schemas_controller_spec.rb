# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::Schemas::SharedSchemasController, type: :request do
  include FixtureHelpers

  def base_path(appeal_type, schema_type)
    "/services/appeals/#{appeal_type}/v2/schemas/#{schema_type}"
  end

  describe '#show' do
    describe "schema type 'non_blank_string'" do
      appeal_types = %w[notice_of_disagreements higher_level_reviews supplemental_claims]

      appeal_types.each do |appeal_type|
        it "renders the 'nonBlankString' schema" do
          get base_path appeal_type, :non_blank_string

          expect(response.status).to eq(200)
          expect(response.body).to include 'nonBlankString'
        end
      end
    end

    describe "schema type 'address'" do
      appeal_types = %w[notice_of_disagreements higher_level_reviews supplemental_claims]

      appeal_types.each do |appeal_type|
        it "renders the 'address' schema" do
          get base_path appeal_type, :address

          expect(response.status).to eq(200)
          expect(response.body).to include 'address'
          expect(response.body).to include 'addressLine1'
        end
      end
    end

    describe "schema type 'date'" do
      appeal_types = %w[notice_of_disagreements higher_level_reviews supplemental_claims]

      appeal_types.each do |appeal_type|
        it "renders the 'date' schema" do
          get base_path appeal_type, :date

          expect(response.status).to eq(200)
          expect(response.body).to include 'date'
          expect(response.body).to include '^[0-9]{4}(-[0-9]{2}){2}$'
        end
      end
    end

    describe "schema type 'phone'" do
      appeal_types = %w[notice_of_disagreements higher_level_reviews supplemental_claims]

      appeal_types.each do |appeal_type|
        it "renders the 'phone' schema" do
          get base_path appeal_type, :phone

          expect(response.status).to eq(200)
          expect(response.body).to include 'phone'
          expect(response.body).to include 'areaCode'
        end
      end
    end

    describe "schema type 'timezone'" do
      appeal_types = %w[notice_of_disagreements higher_level_reviews supplemental_claims]

      appeal_types.each do |appeal_type|
        it "renders the 'timezone' schema" do
          get base_path appeal_type, :timezone

          expect(response.status).to eq(200)
          expect(response.body).to include 'timezone'
          expect(response.body).to include 'Abu Dhabi'
          expect(response.body).to include 'Zurich'
        end
      end
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
