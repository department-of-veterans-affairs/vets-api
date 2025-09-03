# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

RSpec.describe 'V0::IntentToFile', type: :request do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }
  let(:camel_inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:headers_with_camel) { headers.merge('X-Key-Inflection' => 'camel') }
  let(:monitor) { double('monitor') }

  before do
    sign_in_as(user)
    Flipper.disable(:disability_compensation_production_tester)
    Flipper.disable(:pension_itf_skip_missing_person_error_enabled)

    allow(BenefitsClaims::IntentToFile::Monitor).to receive(:new).and_return(monitor)
  end

  describe 'GET /v0/intent_to_file' do
    context 'Lighthouse api provider' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('test_token')
      end

      context 'with a valid Lighthouse response' do
        it 'matches the intent to files schema' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            get '/v0/intent_to_file'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intent_to_files')
          end
        end

        it 'matches the intent to files schema when camel-inflected' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            get '/v0/intent_to_file', headers: camel_inflection_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('intent_to_files')
          end
        end

        it 'does not throw a 403 when user is missing birls_id and edipi' do
          # Stub blank birls_id and blank edipi
          allow(user.identity).to receive(:edipi).and_return(nil)
          allow(user).to receive_messages(edipi_mpi: nil, birls_id: nil)
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            get '/v0/intent_to_file'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intent_to_files')
          end
        end
      end

      context 'for non-compensation ITF types' do
        let(:intent_to_file) do
          {
            'data' => {
              'id' => '193685',
              'type' => 'intent_to_file',
              'attributes' => {
                'creationDate' => '2021-03-16T19:15:21.000-05:00',
                'expirationDate' => '2022-03-16T19:15:20.000-05:00',
                'type' => itf_type,
                'status' => 'active'
              }
            }
          }
        end

        before do
          expect_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file)
            .with(itf_type, anything, nil).and_return(intent_to_file)
        end

        context 'with a pension ITF type' do
          let(:itf_type) { 'pension' }

          it 'matches the intent to files schema' do
            expect(monitor).to receive(:track_show_itf)

            get '/v0/intent_to_file/pension'

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intent_to_files')
            expect(JSON.parse(response.body)['data']['attributes']['intent_to_file'][0]['type']).to eq itf_type
          end
        end

        context 'with a survivor ITF type' do
          let(:itf_type) { 'survivor' }

          it 'matches the intent to files schema' do
            expect(monitor).to receive(:track_show_itf)

            get '/v0/intent_to_file/survivor'

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intent_to_files')
            expect(JSON.parse(response.body)['data']['attributes']['intent_to_file'][0]['type']).to eq itf_type
          end
        end
      end

      context 'error handling tests' do
        [:'404'].each do |status, _error_class|
          error_status = status.to_s.to_i
          cassette_path = "lighthouse/benefits_claims/intent_to_file/#{status}_response"
          it "returns #{status} response" do
            expect(test_error(
                     cassette_path,
                     error_status,
                     headers
                   )).to be(true)
          end

          it "returns a #{status} response with camel-inflection" do
            expect(test_error(
                     cassette_path,
                     error_status,
                     headers_with_camel
                   )).to be(true)
          end
        end

        def test_error(cassette_path, status, headers)
          VCR.use_cassette(cassette_path) do
            expect(monitor).to receive(:track_itf_controller_error)
            get('/v0/intent_to_file', params: nil, headers:)
            expect(response).to have_http_status(status)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end
      end

      context 'data validation and monitoring' do
        subject { V0::IntentToFilesController.new }

        before do
          allow(monitor).to receive(:track_missing_user_icn_itf_controller)
          allow(monitor).to receive(:track_missing_user_pid_itf_controller)
          allow(monitor).to receive(:track_invalid_itf_type_itf_controller)
        end

        it 'raises MissingICNError' do
          user_no_icn = build(:disabilities_compensation_user, icn: nil)

          expect { subject.send(:validate_data, user_no_icn, 'post', 'form_id', 'pension') }
            .to raise_error V0::IntentToFilesController::MissingICNError
          expect(monitor).to have_received(:track_missing_user_icn_itf_controller)
        end

        it 'raises MissingParticipantIDError' do
          user_no_pid = build(:disabilities_compensation_user, participant_id: nil)

          expect { subject.send(:validate_data, user_no_pid, 'get', 'form_id', 'survivor') }
            .to raise_error V0::IntentToFilesController::MissingParticipantIDError

          expect(monitor).to have_received(:track_missing_user_pid_itf_controller)
        end

        it 'skips raising MissingParticipantIDError when flipper is enabled' do
          user_no_pid = build(:disabilities_compensation_user, participant_id: nil)
          allow(Flipper).to receive(:enabled?).with(:pension_itf_skip_missing_person_error_enabled,
                                                    user_no_pid).and_return(true)

          expect { subject.send(:validate_data, user_no_pid, 'get', 'form_id', 'survivor') }
            .not_to raise_error

          expect(monitor).to have_received(:track_missing_user_pid_itf_controller)
        end

        it 'raises MissingParticipantIDError when flipper is disabled' do
          user_no_pid = build(:disabilities_compensation_user, participant_id: nil)
          allow(Flipper).to receive(:enabled?).with(:pension_itf_skip_missing_person_error_enabled,
                                                    user_no_pid).and_return(false)

          expect { subject.send(:validate_data, user_no_pid, 'get', 'form_id', 'survivor') }
            .to raise_error V0::IntentToFilesController::MissingParticipantIDError

          expect(monitor).to have_received(:track_missing_user_pid_itf_controller)
        end

        it 'raises InvalidITFTypeError' do
          expect { subject.send(:validate_data, user, 'get', nil, 'survivor') }
            .to raise_error V0::IntentToFilesController::InvalidITFTypeError

          expect(monitor).to have_received(:track_invalid_itf_type_itf_controller)
        end
      end
    end
  end

  describe 'POST /v0/intent_to_file' do
    before do
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('test_token')
    end

    shared_examples 'create intent to file with specified itf type' do
      let(:intent_to_file) do
        {
          'data' => {
            'id' => '193685',
            'type' => 'intent_to_file',
            'attributes' => {
              'creationDate' => '2021-03-16T19:15:21.000-05:00',
              'expirationDate' => '2022-03-16T19:15:20.000-05:00',
              'type' => itf_type,
              'status' => 'active'
            }
          }
        }
      end

      it 'matches the respective intent to file schema' do
        expect_any_instance_of(BenefitsClaims::Service).to receive(:create_intent_to_file)
          .with(itf_type, user.ssn, nil).and_return(intent_to_file)
        expect(monitor).to receive(:track_submit_itf)

        post "/v0/intent_to_file/#{itf_type}"

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('intent_to_file')
        expect(JSON.parse(response.body)['data']['attributes']['intent_to_file']['type']).to eq itf_type
      end
    end

    context 'when an ITF create request is submitted' do
      it_behaves_like 'create intent to file with specified itf type' do
        let(:itf_type) { 'pension' }
      end
      it_behaves_like 'create intent to file with specified itf type' do
        let(:itf_type) { 'survivor' }
      end
    end
  end
end
