# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/bb_internal/client'
require 'medical_records/client'
require 'mhv/aal/client'
require 'support/mr_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::MedicalRecords::SelfEntered', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '21207668' }
  let(:current_user) { build(:user, :mhv) }
  let(:aal_client) { instance_spy(AAL::MRClient) }

  before do
    allow(AAL::MRClient).to receive(:new).and_return(aal_client)

    bb_internal_client = BBInternal::Client.new(
      session: {
        user_id: 11_375_034,
        patient_id: '11382904',
        expires_at: 1.hour.from_now,
        token: '<SESSION_TOKEN>'
      }
    )

    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_new_eligibility_check).and_return(false)
    allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)
    sign_in_as(current_user)
  end

  context 'Unauthorized user' do
    context 'with no MHV Correlation ID' do
      let(:invalid_user) { build(:user) }

      before do
        sign_in_as(invalid_user)
      end

      it 'returns 403 Forbidden when mhv_correlation_id is missing' do
        sign_in_as(invalid_user)

        get '/my_health/v1/medical_records/self_entered'

        expect(invalid_user.icn).not_to be_nil
        expect(invalid_user.mhv_correlation_id).to be_nil
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['errors'].first['detail']).to eq('Unable to access MHV services. Please try signing in again.')
      end
    end

    context 'with no ICN' do
      let(:invalid_user) { build(:user, :mhv, icn: nil) }

      before do
        sign_in_as(invalid_user)
      end

      it 'returns 403 Forbidden when icn is missing' do
        sign_in_as(invalid_user)

        get '/my_health/v1/medical_records/self_entered'

        expect(invalid_user.icn).to be_nil
        expect(invalid_user.mhv_correlation_id).not_to be_nil
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['errors'].first['detail']).to eq('You do not have access to self-entered information')
      end
    end
  end

  context 'Authorized user' do
    it 'responds to GET #index' do
      VCR.use_cassette('mr_client/get_self_entered_information') do
        get '/my_health/v1/medical_records/self_entered'
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)
      expect(json['responses'].size).to eq 15 # There should be 15 successful API responses
      expect(json['errors'].size).to eq 0

      expect_aal_logged(1)
    end

    context 'when one of the upstream calls error out with a 502 XML error' do
      # Test that the :mhv_xml_html_errors middleware is bypassed
      it 'reports an error for one service but still succeeds overall' do
        VCR.use_cassette('mr_client/get_self_entered_information_502') do
          get '/my_health/v1/medical_records/self_entered'
        end

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)

        json = JSON.parse(response.body)
        expect(json['errors']).to be_a(Hash)
        expect(json['errors'].keys).to contain_exactly('allergies')
        json['errors'].each_value do |details|
          expect(details['message']).to match(/502 Bad Gateway/)
        end

        expect(json['responses'].size).to eq(14) # 15 total - 1 failure

        expect_aal_logged(1)
      end
    end

    context 'when some of the upstream calls error out with non-XML/HTML responses' do
      # Test that the :raise_custom_error middleware is bypassed
      let(:allergy_error_response) do
        instance_double(
          Faraday::Response,
          success?: false,
          status: 500,
          body: 'allergy service is down',
          reason_phrase: 'Internal Server Error'
        )
      end

      let(:immunization_error_response) do
        instance_double(
          Faraday::Response,
          success?: false,
          status: 504,
          body: 'immunization timeout',
          reason_phrase: 'Gateway Timeout'
        )
      end

      before do
        allow_any_instance_of(BBInternal::Client)
          .to receive(:get_sei_allergies)
          .and_return(allergy_error_response)

        allow_any_instance_of(BBInternal::Client)
          .to receive(:get_sei_immunizations)
          .and_return(immunization_error_response)
      end

      it 'returns errors for some services but still succeeds overall' do
        VCR.use_cassette('mr_client/get_self_entered_information') do
          get '/my_health/v1/medical_records/self_entered'
        end

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)

        json = JSON.parse(response.body)
        expect(json['errors']).to be_a(Hash)
        expect(json['errors'].keys).to contain_exactly('allergies', 'vaccines')
        json['errors'].each_value do |details|
          expect(details['message']).to match(/service is down|timeout/)
        end

        expect(json['responses'].size).to eq(13) # 15 total - 2 failures

        expect_aal_logged(1)
      end
    end

    context 'when the entire call fails' do
      before do
        allow_any_instance_of(BBInternal::Client)
          .to receive(:get_all_sei_data)
          .and_raise(StandardError.new('SEI error'))
      end

      it 'returns an overall error' do
        get '/my_health/v1/medical_records/self_entered'

        expect(response).to have_http_status(:internal_server_error)

        expect_aal_logged(0)
      end
    end
  end

  def expect_aal_logged(status)
    expect(aal_client).to have_received(:create_aal).with(
      hash_including(
        activity_type: 'Self entered health information',
        action: 'Download',
        performer_type: 'Self',
        status:
      ),
      true,
      anything # unique session ID could be different things depending on how it's implemented
    )
  end
end
