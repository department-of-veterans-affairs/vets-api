# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V2::ClinicalNotesController', :skip_json_api_validation, type: :request do
  let(:user_id) { '11898795' }
  let(:default_params) { { start_date: '2024-01-01', end_date: '2025-05-31' } }
  let(:path) { '/my_health/v2/medical_records/clinical_notes' }

  let(:uhd_flipper) { :mhv_accelerated_delivery_uhd_enabled }
  let(:notes_flipper) { :mhv_accelerated_delivery_care_notes_enabled }

  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
    allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
    allow(Flipper).to receive(:enabled?).with(notes_flipper, instance_of(User)).and_return(true)
  end

  describe 'GET /my_health/v2/medical_records/notes#index' do
    context 'happy path' do
      it 'returns a successful response' do
        VCR.use_cassette('unified_health_data/get_clinical_notes_200') do
          get '/my_health/v2/medical_records/clinical_notes', headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['data'].count).to eq(2)
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].first['type']).to eq('clinical_note')
        expect(json_response['data'].first).to include(
          'id',
          'type',
          'attributes'
        )
        expect(json_response['data'].first['attributes']).to include(
          'id',
          'name',
          'type',
          'date',
          'dateSigned',
          'writtenBy',
          'signedBy',
          'location',
          'note'
        )
      end

      it 'returns a successful response with an empty data array' do
        VCR.use_cassette('unified_health_data/get_clinical_notes_no_records') do
          get '/my_health/v2/medical_records/clinical_notes',
              headers: { 'X-Key-Inflection' => 'camel' }
        end
        expect(response).to be_successful
        json_response = JSON.parse(response.body)

        expect(json_response['data']).to eq([])
      end
    end
  end
end
