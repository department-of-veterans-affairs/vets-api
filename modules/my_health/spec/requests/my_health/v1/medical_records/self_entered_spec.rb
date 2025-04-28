# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::MedicalRecords::SelfEntered', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '21207668' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)

    bb_internal_client = BBInternal::Client.new(
      session: {
        user_id: 11_375_034,
        icn: '1000000000V000000',
        patient_id: '11382904',
        expires_at: 1.hour.from_now,
        token: 'ENC(MA0ECJh1RjEgZFMhAgEQCInE+QaILWiZuYg8kVN8DWfIkyTzdhd0XoP+zfs8R2nfXGJ+KEBTLhp8)'
      }
    )

    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)
    sign_in_as(current_user)
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    before do
      VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                          match_requests_on: %i[method sm_user_ignoring_path_param])
    end

    after do
      VCR.eject_cassette
    end

    it 'responds to GET #index' do
      VCR.use_cassette('mr_client/get_self_entered_information') do
        get '/my_health/v1/medical_records/self_entered'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)
      expect(json['responses'].size).to eq 15 # There should be 15 successful API responses
      expect(json['errors'].size).to eq 0 # There should be 15 successful API responses
    end

    context 'when some of the downstream calls error out' do
      before do
        # stub those two service methods to raise:
        allow_any_instance_of(BBInternal::Client)
          .to receive(:get_sei_allergies)
          .and_raise(StandardError.new('allergy service is down'))

        allow_any_instance_of(BBInternal::Client)
          .to receive(:get_sei_immunizations)
          .and_raise(StandardError.new('immunization timeout'))
      end

      it 'returns errors for some services but still succeeds overall' do
        VCR.use_cassette('mr_client/get_self_entered_information') do
          get '/my_health/v1/medical_records/self_entered'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        json = JSON.parse(response.body)

        expect(json['errors']).to be_a(Hash)
        expect(json['errors'].keys).to contain_exactly('allergies', 'vaccines')
        json['errors'].each_value do |details|
          expect(details['message']).to match(/service is down|timeout/)
        end

        expect(json['responses'].size).to eq(13) # 15 total - 2 failures
      end
    end
  end
end
