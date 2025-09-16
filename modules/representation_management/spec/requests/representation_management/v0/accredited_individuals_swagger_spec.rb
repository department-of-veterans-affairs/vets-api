# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require_relative '../../../support/swagger_shared_components/v0'

RSpec.describe 'Accredited Individuals',
               openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
               type: :request do
  before do
    allow(Flipper).to receive(:enabled?).with(:find_a_representative_use_accredited_models).and_return(true)

    create(:accredited_individual,
           :with_location,
           first_name: 'Bob',
           last_name: 'Law',
           full_name: 'Bob Law',
           address_type: 'Domestic',
           address_line1: '123 Main St',
           city: 'Anytown',
           country_name: 'USA',
           country_code_iso3: 'USA',
           province: 'New York',
           state_code: 'NY',
           zip_code: '12345',
           phone: '123-456-7890',
           email: 'boblaw@example.com',
           individual_type: 'attorney')
  end

  path '/representation_management/v0/accredited_individuals' do
    get('Search for accredited individuals') do
      tags 'Accredited Individuals'
      consumes 'application/json'
      produces 'application/json'
      operationId 'searchAccreditedIndividuals'
      description 'Returns accredited individuals based on search criteria including location and type'

      parameter name: :lat, in: :query, type: :number, format: :float, required: true,
                description: 'Latitude coordinate', example: 40.7128
      parameter name: :long, in: :query, type: :number, format: :float, required: true,
                description: 'Longitude coordinate', example: -74.0060
      parameter name: :type, in: :query, type: :string, required: true,
                description: 'Type of accredited individual',
                enum: %w[attorney claims_agent vso_representative],
                example: 'attorney'
      parameter name: :distance, in: :query, type: :integer,
                description: 'Maximum distance in miles', example: 50
      parameter name: :name, in: :query, type: :string,
                description: 'Name to search for', example: 'Bob Law'
      parameter name: :page, in: :query, type: :integer,
                description: 'Page number', example: 1
      parameter name: :per_page, in: :query, type: :integer,
                description: 'Number of results per page', example: 10
      parameter name: :sort, in: :query, type: :string,
                description: 'Sort order',
                enum: %w[distance_asc first_name_asc first_name_desc last_name_asc last_name_desc],
                example: 'distance_asc'

      response '200', 'OK' do
        let(:lat) { 40.7128 }
        let(:long) { -74.0060 }
        let(:type) { 'attorney' } # Query parameter - doesn't conflict with RSpec's type: :request
        let(:distance) { 50 }
        let(:name) { 'Bob Law' }
        let(:page) { 1 }
        let(:per_page) { 10 }
        let(:sort) { 'distance_asc' }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/accreditedIndividual' }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     pagination: {
                       type: :object,
                       properties: {
                         current_page: { type: :integer, example: 1 },
                         per_page: { type: :integer, example: 10 },
                         total_pages: { type: :integer, example: 1 },
                         total_entries: { type: :integer, example: 1 }
                       }
                     }
                   }
                 }
               }
        run_test!
      end

      response '400', 'bad request response' do
        let(:lat) { nil }
        let(:long) { nil }
        let(:type) { nil }
        let(:distance) { nil }
        let(:name) { nil }
        let(:page) { nil }
        let(:per_page) { nil }
        let(:sort) { nil }

        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       title: { type: :string },
                       detail: { type: :string },
                       code: { type: :string },
                       status: { type: :string }
                     }
                   }
                 }
               }
        run_test!
      end

      response '422', 'unprocessable entity response' do
        let(:lat) { 40.7128 }
        let(:long) { -74.0060 }
        let(:type) { 'invalid_type' }
        let(:distance) { nil }
        let(:name) { nil }
        let(:page) { nil }
        let(:per_page) { nil }
        let(:sort) { nil }

        schema '$ref' => '#/components/schemas/errors'
        run_test!
      end
    end
  end
end
