# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/direct_deposit/configuration'
require 'support/bb_client_helpers'
require 'support/pagerduty/services/spec_setup'
require 'support/stub_debt_letters'
require 'support/medical_copays/stub_medical_copays'
require 'support/stub_efolder_documents'
require_relative '../../../modules/debts_api/spec/support/stub_financial_status_report'
require 'bgs/service'
require 'sign_in/logingov/service'
require 'hca/enrollment_eligibility/constants'
require 'form1010_ezr/service'
require 'lighthouse/facilities/v1/client'
require 'debts_api/v0/digital_dispute_submission_service'

RSpec.describe 'the v0 API documentation (Part 6)', order: :defined, type: %i[apivore request] do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob') }

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid)
    end

    describe 'profile/status v2', :initiate_vaprofile, :skip_vet360 do
      let(:user) { build(:user, :loa3, uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef', should_stub_mpi: false) }

      before do
        sign_in_as(user)
      end

      it 'supports GETting async transaction by ID' do
        transaction = create(
          :va_profile_address_transaction,
          transaction_id: '0ea91332-4713-4008-bd57-40541ee8d4d4',
          user_uuid: user.uuid,
          user_account_id: user.user_account_uuid
        )

        expect(subject).to validate(
          :get,
          '/v0/profile/status/{transaction_id}',
          401,
          'transaction_id' => transaction.transaction_id
        )

        VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
          expect(subject).to validate(
            :get,
            '/v0/profile/status/{transaction_id}',
            200,
            headers.merge('transaction_id' => transaction.transaction_id)
          )
        end
      end

      it 'supports GETting async transactions by user' do
        expect(subject).to validate(
          :get,
          '/v0/profile/status/',
          401
        )

        VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
          expect(subject).to validate(
            :get,
            '/v0/profile/status/',
            200,
            headers
          )
        end
      end
    end

    describe 'profile/person/status/:transaction_id v2' do
      let(:user_without_vet360_id) { build(:user, :loa3) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user_without_vet360_id, nil, true) } } }

      before do
        allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
        allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
        sign_in_as(user_without_vet360_id)
      end

      it 'supports GETting async person transaction by transaction ID' do
        transaction_id = '153536a5-8b18-4572-a3d9-4030bea3ab5c'
        transaction = create(
          :va_profile_initialize_person_transaction,
          :init_vet360_id,
          user_uuid: user_without_vet360_id.uuid,
          transaction_id:
        )

        expect(subject).to validate(
          :get,
          '/v0/profile/person/status/{transaction_id}',
          401,
          'transaction_id' => transaction.transaction_id
        )

        VCR.use_cassette('va_profile/v2/contact_information/person_transaction_status') do
          expect(subject).to validate(
            :get,
            '/v0/profile/person/status/{transaction_id}',
            200,
            headers.merge('transaction_id' => transaction.transaction_id)
          )
        end
      end
    end

    describe 'profile/connected_applications' do
      let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
      let(:user) { create(:user, :loa3, :legacy_icn) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, token, true) } } }

      before do
        Session.create(uuid: user.uuid, token:)
      end

      it 'supports getting connected applications' do
        expect(subject).to validate(:get, '/v0/profile/connected_applications', 401)
        VCR.use_cassette('lighthouse/auth/client_credentials/connected_apps_200') do
          expect(subject).to validate(:get, '/v0/profile/connected_applications', 200, headers)
        end
      end

      it 'supports removing connected applications grants' do
        parameters = { 'application_id' => '0oa2ey2m6kEL2897N2p7' }
        expect(subject).to validate(:delete, '/v0/profile/connected_applications/{application_id}', 401, parameters)
        VCR.use_cassette('lighthouse/auth/client_credentials/revoke_consent_204', allow_playback_repeats: true) do
          expect(subject).to(
            validate(
              :delete,
              '/v0/profile/connected_applications/{application_id}',
              204,
              headers.merge(parameters)
            )
          )
        end
      end
    end

    describe 'when MVI returns an unexpected response body' do
      it 'supports returning a custom 502 response' do
        allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return({
                                                                              service_name: 'oauth_IDME',
                                                                              auth_broker: 'IDME'
                                                                            })

        allow_any_instance_of(MPI::Models::MviProfile).to receive(:gender).and_return(nil)
        allow_any_instance_of(MPI::Models::MviProfile).to receive(:birth_date).and_return(nil)

        VCR.use_cassette('mpi/find_candidate/missing_birthday_and_gender') do
          VCR.use_cassette('va_profile/demographics/demographics') do
            expect(subject).to validate(:get, '/v0/profile/personal_information', 502, headers)
          end
        end
      end
    end

    describe 'when VA Profile returns an unexpected response body' do
      it 'supports returning a custom 400 response' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500') do
          expect(subject).to validate(:get, '/v0/profile/service_history', 400, headers)
        end
      end
    end

    describe 'search' do
      before do
        Flipper.disable(:search_use_v2_gsa)
      end

      context 'when successful' do
        it 'supports getting search results data' do
          VCR.use_cassette('search/success') do
            expect(subject).to validate(:get, '/v0/search', 200, '_query_string' => 'query=benefits')
          end
        end
      end

      context 'with an empty search query' do
        it 'returns a 400 with error details' do
          VCR.use_cassette('search/empty_query') do
            expect(subject).to validate(:get, '/v0/search', 400, '_query_string' => 'query=')
          end
        end
      end

      context 'when the Search.gov rate limit has been exceeded' do
        it 'returns a 429 with error details' do
          VCR.use_cassette('search/exceeds_rate_limit') do
            expect(subject).to validate(:get, '/v0/search', 429, '_query_string' => 'query=benefits')
          end
        end
      end
    end

    describe 'search click tracking' do
      context 'when successful' do
        # rubocop:disable Layout/LineLength
        let(:params) { { 'position' => 0, 'query' => 'testQuery', 'url' => 'https%3A%2F%2Fwww.testurl.com', 'user_agent' => 'testUserAgent', 'module_code' => 'I14Y' } }

        it 'sends data as query params' do
          VCR.use_cassette('search_click_tracking/success') do
            expect(subject).to validate(:post, '/v0/search_click_tracking/?position={position}&query={query}&url={url}&module_code={module_code}&user_agent={user_agent}', 204, params)
          end
        end
      end

      context 'with an empty search query' do
        let(:params) { { 'position' => 0, 'query' => '', 'url' => 'https%3A%2F%2Fwww.testurl.com', 'user_agent' => 'testUserAgent', 'module_code' => 'I14Y' } }

        it 'returns a 400 with error details' do
          VCR.use_cassette('search_click_tracking/missing_parameter') do
            expect(subject).to validate(:post, '/v0/search_click_tracking/?position={position}&query={query}&url={url}&module_code={module_code}&user_agent={user_agent}', 400, params)
          end
          # rubocop:enable Layout/LineLength
        end
      end
    end

    describe 'search typeahead' do
      context 'when successful' do
        it 'returns an array of suggestions' do
          VCR.use_cassette('search_typeahead/success') do
            expect(subject).to validate(:get, '/v0/search_typeahead', 200, '_query_string' => 'query=ebenefits')
          end
        end
      end

      context 'with an empty search query' do
        it 'returns a 200 with empty results' do
          VCR.use_cassette('search_typeahead/missing_query') do
            expect(subject).to validate(:get, '/v0/search_typeahead', 200, '_query_string' => 'query=')
          end
        end
      end
    end

    describe 'forms' do
      context 'when successful' do
        it 'supports getting form results data with a query' do
          VCR.use_cassette('forms/200_form_query') do
            expect(subject).to validate(:get, '/v0/forms', 200, '_query_string' => 'query=health')
          end
        end

        it 'support getting form results without a query' do
          VCR.use_cassette('forms/200_all_forms') do
            expect(subject).to validate(:get, '/v0/forms', 200)
          end
        end
      end
    end

    describe '1095-B' do
      let(:user) { build(:user, :loa3, icn: '3456787654324567') }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }
      let(:bad_headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

      before do
        create(:form1095_b, tax_year: Form1095B.current_tax_year)
      end

      context 'available forms' do
        it 'supports getting available forms' do
          expect(subject).to validate(
            :get,
            '/v0/form1095_bs/available_forms',
            200,
            headers
          )
        end

        it 'requires authorization' do
          expect(subject).to validate(
            :get,
            '/v0/form1095_bs/available_forms',
            401
          )
        end
      end
    end

    describe 'contact us' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
      end

      describe 'POST v0/contact_us/inquiries' do
        let(:post_body) do
          {
            inquiry: {
              form: JSON.generate(
                {
                  personalInformation: {
                    first: 'Obi Wan',
                    last: 'Kenobi'
                  },
                  contactInformation: {
                    email: 'obi1kenobi@gmail.com',
                    address: {
                      country: 'USA'
                    },
                    phone: '1234567890'
                  },
                  topic: {
                    levelOne: 'Caregiver Support Program',
                    levelTwo: 'VA Supportive Services'
                  },
                  inquiryType: 'Question',
                  query: 'Can you help me?',
                  veteranStatus: {
                    veteranStatus: 'general'
                  },
                  preferredContactMethod: 'email'
                }
              )
            }
          }
        end

        it 'supports posting contact us form data' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

          expect(subject).to validate(
            :post,
            '/v0/contact_us/inquiries',
            201,
            headers.merge('_data' => post_body)
          )
        end

        it 'supports validating posted contact us form data' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

          expect(subject).to validate(
            :post,
            '/v0/contact_us/inquiries',
            422,
            headers.merge(
              '_data' => {
                'inquiry' => {
                  'form' => {}.to_json
                }
              }
            )
          )
        end

        it 'supports 501 when feature is disabled' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(false)

          expect(subject).to validate(
            :post,
            '/v0/contact_us/inquiries',
            501,
            headers.merge(
              '_data' => {
                'inquiry' => {
                  'form' => {}.to_json
                }
              }
            )
          )
        end
      end

      describe 'GET v0/contact_us/inquiries' do
        context 'logged in' do
          let(:user) { build(:user, :loa3) }
          let(:headers) do
            { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          end

          it 'supports getting list of inquiries sent by user' do
            expect(Flipper).to receive(:enabled?).with(:get_help_messages).and_return(true)

            expect(subject).to validate(:get, '/v0/contact_us/inquiries', 200, headers)
          end
        end

        context 'not logged in' do
          it 'returns a 401' do
            expect(subject).to validate(:get, '/v0/contact_us/inquiries', 401)
          end
        end
      end
    end

    describe 'dependents applications' do
      context 'when :va_dependents_v2 is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
        end

        let!(:user) { build(:user, ssn: '796043735') }

        it 'supports getting dependent information' do
          expect(subject).to validate(:get, '/v0/dependents_applications/show', 401)
          VCR.use_cassette('bgs/claimant_web_service/dependents') do
            expect(subject).to validate(:get, '/v0/dependents_applications/show', 200, headers)
          end
        end

        it 'supports adding a dependency claim' do
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(false)
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
          allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            expect(subject).to validate(
              :post,
              '/v0/dependents_applications',
              200,
              headers.merge(
                '_data' => build(:dependency_claim).parsed_form
              )
            )
          end

          expect(subject).to validate(
            :post,
            '/v0/dependents_applications',
            422,
            headers.merge(
              '_data' => {
                'dependency_claim' => {
                  'invalid-form' => { invalid: true }.to_json
                }
              }
            )
          )
        end
      end

      context 'when :va_dependents_v2 is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
        end

        let!(:user) { build(:user, ssn: '796043735') }

        it 'supports getting dependent information' do
          expect(subject).to validate(:get, '/v0/dependents_applications/show', 401)
          VCR.use_cassette('bgs/claimant_web_service/dependents') do
            expect(subject).to validate(:get, '/v0/dependents_applications/show', 200, headers)
          end
        end

        it 'supports adding a dependency claim' do
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(false)
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
          allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            expect(subject).to validate(
              :post,
              '/v0/dependents_applications',
              200,
              headers.merge(
                '_data' => build(:dependency_claim).parsed_form
              )
            )
          end

          expect(subject).to validate(
            :post,
            '/v0/dependents_applications',
            422,
            headers.merge(
              '_data' => {
                'dependency_claim' => {
                  'invalid-form' => { invalid: true }.to_json
                }
              }
            )
          )
        end
      end
    end

    describe 'dependents verifications' do
      it 'supports getting diary information' do
        expect(subject).to validate(:get, '/v0/dependents_verifications', 401)
        VCR.use_cassette('bgs/diaries/read') do
          expect(subject).to validate(:get, '/v0/dependents_verifications', 200, headers)
        end
      end

      it 'supports updating diaries' do
        expect(subject).to validate(
          :post,
          '/v0/dependents_verifications',
          200,
          headers.merge(
            '_data' => {
              'dependency_verification_claim' => {
                'form' => { 'update_diaries' => 'true' }
              }
            }
          )
        )
      end
    end

    describe 'education career counseling claims' do
      it 'supports adding a career counseling claim' do
        expect(subject).to validate(
          :post,
          '/v0/education_career_counseling_claims',
          200,
          headers.merge(
            '_data' => {
              'education_career_counseling_claim' => {
                form: build(:education_career_counseling_claim).form
              }
            }
          )
        )

        expect(subject).to validate(
          :post,
          '/v0/education_career_counseling_claims',
          422,
          headers.merge(
            '_data' => {
              'education_career_counseling_claim' => {
                'invalid-form' => { invalid: true }.to_json
              }
            }
          )
        )
      end
    end

    describe 'veteran readiness employment claims' do
      it 'supports adding veteran readiness employment claim' do
        VCR.use_cassette('veteran_readiness_employment/send_to_vre') do
          allow(ClaimsApi::VBMSUploader).to receive(:new) { OpenStruct.new(upload!: true) }
          expect(subject).to validate(
            :post,
            '/v0/veteran_readiness_employment_claims',
            200,
            headers.merge(
              '_data' => {
                'veteran_readiness_employment_claim' => {
                  form: build(:veteran_readiness_employment_claim).form
                }
              }
            )
          )
        end
      end

      it 'throws an error when adding veteran readiness employment claim' do
        expect(subject).to validate(
          :post,
          '/v0/veteran_readiness_employment_claims',
          422,
          headers.merge(
            '_data' => {
              'veteran_readiness_employment_claim' => {
                'invalid-form' => { invalid: true }.to_json
              }
            }
          )
        )
      end
    end

    describe 'va file number' do
      it 'supports checking if a user has a veteran number' do
        expect(subject).to validate(:get, '/v0/profile/valid_va_file_number', 401)
        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          expect(subject).to validate(:get, '/v0/profile/valid_va_file_number', 200, headers)
        end
      end
    end

    it "supports returning the vet's payment_history" do
      expect(subject).to validate(:get, '/v0/profile/payment_history', 401)
      VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
        expect(subject).to validate(:get, '/v0/profile/payment_history', 200, headers)
      end
    end
  end
end