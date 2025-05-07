# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'
require 'support/shared_examples_for_mhv'

# rubocop:disable Layout/LineLength
RSpec.describe 'V0::Prescriptions', type: :request do
  include Rx::ClientHelpers
  include SchemaMatchers

  let(:va_patient) { true }
  let(:current_user) do
    build(:user, :mhv, authn_context: LOA::IDME_LOA3_VETS,
                       va_patient:,
                       mhv_account_type:,
                       sign_in: { service_name: SignIn::Constants::Auth::IDME })
  end
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_migrate_to_api_gateway).and_return(false)
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { get '/v0/prescriptions/13651310' }

    include_examples 'for user account level', message: 'You do not have access to prescriptions'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to prescriptions'
  end

  %w[Premium Advanced].each do |account_level|
    context "#{account_level} User" do
      let(:mhv_account_type) { account_level }

      context 'not a va patient' do
        before { get '/v0/prescriptions/13651310' }

        let(:va_patient) { false }
        let(:current_user) do
          build(:user,
                :mhv,
                :no_vha_facilities,
                authn_context: LOA::IDME_LOA3_VETS,
                va_patient:,
                mhv_account_type:,
                sign_in: { service_name: SignIn::Constants::Auth::IDME })
        end

        include_examples 'for non va patient user', authorized: false, message: 'You do not have access to prescriptions'
      end

      it 'responds to GET #show' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
          get '/v0/prescriptions/13651310'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('prescription')
      end

      it 'responds to GET #show with camel-inlfection' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
          get '/v0/prescriptions/13651310', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('prescription')
      end

      it 'responds to GET #index with no parameters' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
          get '/v0/prescriptions'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('prescriptions')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('prescription_name' => 'ASC')
      end

      it 'responds to GET #index with no parameters when camel-inflected' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
          get '/v0/prescriptions', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('prescriptions')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('prescriptionName' => 'ASC')
      end

      it 'responds to GET #index with refill_status=active' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions') do
          get '/v0/prescriptions?refill_status=active'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('prescriptions')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('prescription_name' => 'ASC')
      end

      it 'responds to GET #index with refill_status=active when camel-inflected' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions') do
          get '/v0/prescriptions?refill_status=active', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('prescriptions')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('prescriptionName' => 'ASC')
      end

      it 'responds to GET #index with filter' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
          get '/v0/prescriptions?filter[[refill_status][eq]]=refillinprocess'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('prescriptions_filtered')
      end

      it 'responds to GET #index with filter when camel-inflected' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
          get '/v0/prescriptions?filter[[refill_status][eq]]=refillinprocess', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('prescriptions_filtered')
      end

      it 'responds to PATCH #refill' do
        VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
          patch '/v0/prescriptions/13650545/refill'
        end

        expect(response).to be_successful
        expect(response.body).to be_empty
      end

      context 'nested resources' do
        it 'responds to GET #show of nested tracking resource' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_a_list_of_tracking_history_for_a_prescription') do
            get '/v0/prescriptions/13650541/trackings'
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('trackings')
          expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
        end

        it 'responds to GET #show of nested tracking resource when camel-inflected' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_a_list_of_tracking_history_for_a_prescription') do
            get '/v0/prescriptions/13650541/trackings', headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('trackings')
          expect(JSON.parse(response.body)['meta']['sort']).to eq('shippedDate' => 'DESC')
        end

        it 'responds to GET #show of nested tracking resource with a shipment having no other prescriptions' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_with_empty_other_prescriptions') do
            get '/v0/prescriptions/13650541/trackings'
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('trackings')
          expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
        end

        it 'responds to GET #show of nested tracking resource with a shipment having no other prescriptions when camel-inflected' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_with_empty_other_prescriptions') do
            get '/v0/prescriptions/13650541/trackings', headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('trackings')
          expect(JSON.parse(response.body)['meta']['sort']).to eq('shippedDate' => 'DESC')
        end
      end

      context 'preferences' do
        it 'responds to GET #show of preferences' do
          VCR.use_cassette('rx_client/preferences/gets_rx_preferences') do
            get '/v0/prescriptions/preferences'
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          attrs = JSON.parse(response.body)['data']['attributes']
          expect(attrs['email_address']).to eq('Praneeth.Gaganapally@va.gov')
          expect(attrs['rx_flag']).to be true
        end

        it 'responds to PUT #update of preferences' do
          VCR.use_cassette('rx_client/preferences/sets_rx_preferences', record: :none) do
            params = { email_address: 'kamyar.karshenas@va.gov',
                       rx_flag: false }
            put '/v0/prescriptions/preferences', params:
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['id'])
            .to eq('59623c5f11b874409315b05a254a7ace5f6a1b12a21334f7b3ceebe1f1854948')
          expect(JSON.parse(response.body)['data']['attributes'])
            .to eq('email_address' => 'kamyar.karshenas@va.gov', 'rx_flag' => false)
        end

        it 'requires all parameters for update' do
          VCR.use_cassette('rx_client/preferences/sets_rx_preferences', record: :none) do
            params = { email_address: 'kamyar.karshenas@va.gov' }
            put '/v0/prescriptions/preferences', params:
          end

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'returns a custom exception mapped from i18n when email contains spaces' do
          VCR.use_cassette('rx_client/preferences/raises_a_backend_service_exception_when_email_includes_spaces') do
            params = { email_address: 'kamyar karshenas@va.gov',
                       rx_flag: false }
            put '/v0/prescriptions/preferences', params:
          end

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['errors'].first['code']).to eq('RX157')
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
