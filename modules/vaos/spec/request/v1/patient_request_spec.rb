# frozen_string_literal: true

RSpec.describe 'VAOS::V1::Patient', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'with loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    it 'returns a forbidden error' do
      get '/vaos/v1/Patient'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['issue'].first.dig('details', 'text'))
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with loa3 user' do
    let(:user) { FactoryBot.create(:user, :loa3) }

    describe 'GET /vaos/v1/Patient?queries' do
      context 'when records are found via identifier' do
        let(:expected_body) do
          YAML.load_file(
            Rails.root.join(
              'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'patient', 'search_200.yml'
            )
          )['http_interactions'].first.dig('response', 'body', 'string')
        end

        # TODO: cassettes need to be created
        xit 'returns a 200' do
          VCR.use_cassette('vaos/fhir/patient/search_200', record: :new_episodes) do
            get '/vaos/v1/Patient?identifier=identifier-value'

            # expect(response).to have_http_status(:ok)
            # expect(response.body).to eq(expected_body)
          end
        end
      end

      # TODO: cassettes  need to be created
      context 'when records are not found' do
        xit 'returns a 404 operation outcome' do
          VCR.use_cassette('vaos/fhir/patient/read_404', record: :new_episodes) do
            get '/vaos/v1/Patient?identifier=identifier-value'

            # expect(response).to have_http_status(:not_found)
            # expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_404')
          end
        end
      end

      # TODO: cassettes need to be created
      context 'when there is an internal FHIR server error' do
        xit 'turns a 502 operation outcome' do
          VCR.use_cassette('vaos/fhir/patient/read_500', record: :new_episodes) do
            get '/vaos/v1/Patient/identifier=identifier-value'

            # expect(response).to have_http_status(:bad_gateway)
            # expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_502')
          end
        end
      end
    end
  end
end
