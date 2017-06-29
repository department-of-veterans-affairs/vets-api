# frozen_string_literal: true
require 'rails_helper'

require 'saml/settings_service'

require 'sm/client'
require 'support/sm_client_helpers'

require 'rx/client'
require 'support/rx_client_helpers'

RSpec.describe 'API doc validations', type: :request do
  context 'json validation' do
    it 'has valid json' do
      get '/v0/apidocs.json'
      json = response.body
      JSON.parse(json).to_yaml
    end
  end
end

RSpec.describe 'the API documentation', type: :apivore, order: :defined do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:rubysaml_settings) { build(:rubysaml_settings) }
  let(:token) { 'lemmein' }
  let(:mhv_account) do
    double('mhv_account', account_state: 'updated',
                          ineligible?: false,
                          eligible?: true,
                          needs_terms_acceptance?: false,
                          upgraded?: true)
  end
  let(:mhv_user) { build :mhv_user }

  before do
    Session.create(uuid: mhv_user.uuid, token: token)
    User.create(mhv_user)
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    allow(SAML::SettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
  end

  context 'has valid paths' do
    let(:auth_options) { { '_headers' => { 'Authorization' => "Token token=#{token}" } } }

    it 'supports new sessions' do
      expect(subject).to validate(:get, '/v0/sessions/new', 200, level: 1)
    end

    it 'supports session deletion' do
      expect(subject).to validate(:delete, '/v0/sessions', 202, auth_options)
      expect(subject).to validate(:delete, '/v0/sessions', 401)
    end

    it 'supports listing in-progress forms' do
      expect(subject).to validate(:get, '/v0/in_progress_forms', 200, auth_options)
      expect(subject).to validate(:get, '/v0/in_progress_forms', 401)
    end

    it 'supports getting an in-progress form' do
      FactoryGirl.create(:in_progress_form, user_uuid: mhv_user.uuid)
      expect(subject).to validate(
        :get,
        '/v0/in_progress_forms/{id}',
        200,
        auth_options.merge('id' => '1010ez')
      )
      expect(subject).to validate(:get, '/v0/in_progress_forms/{id}', 401, 'id' => '1010ez')
    end

    it 'supports updating an in-progress form' do
      expect(subject).to validate(
        :put,
        '/v0/in_progress_forms/{id}',
        200,
        auth_options.merge(
          'id' => '1010ez',
          '_data' => { 'form_data' => { wat: 'foo' } }
        )
      )
      expect(subject).to validate(
        :put,
        '/v0/in_progress_forms/{id}',
        500,
        auth_options.merge('id' => '1010ez')
      )
      expect(subject).to validate(:put, '/v0/in_progress_forms/{id}', 401, 'id' => '1010ez')
    end

    it 'supports deleting an in-progress form' do
      form = FactoryGirl.create(:in_progress_form, user_uuid: mhv_user.uuid)
      expect(subject).to validate(
        :delete,
        '/v0/in_progress_forms/{id}',
        200,
        auth_options.merge('id' => form.form_id)
      )
      expect(subject).to validate(:delete, '/v0/in_progress_forms/{id}', 401, 'id' => form.form_id)
    end

    it 'supports adding an education benefits form' do
      expect(subject).to validate(
        :post,
        '/v0/education_benefits_claims/{form_type}',
        200,
        'form_type' => '1990',
        '_data' => {
          'education_benefits_claim' => {
            'form' => build(:education_benefits_claim).form
          }
        }
      )

      expect(subject).to validate(
        :post,
        '/v0/education_benefits_claims/{form_type}',
        422,
        'form_type' => '1990',
        '_data' => {
          'education_benefits_claim' => {
            'form' => {}.to_json
          }
        }
      )
    end

    it 'supports adding a pension' do
      expect(subject).to validate(
        :post,
        '/v0/pension_claims',
        200,
        '_data' => {
          'pension_claim' => {
            'form' => build(:pension_claim).form
          }
        }
      )

      expect(subject).to validate(
        :post,
        '/v0/pension_claims',
        422,
        '_data' => {
          'pension_claim' => {
            'invalid-form' => { invalid: true }.to_json
          }
        }
      )
    end

    it 'supports adding a burial claim' do
      expect(subject).to validate(
        :post,
        '/v0/burial_claims',
        200,
        '_data' => {
          'burial_claim' => {
            'form' => build(:burial_claim).form
          }
        }
      )

      expect(subject).to validate(
        :post,
        '/v0/burial_claims',
        422,
        '_data' => {
          'burial_claim' => {
            'invalid-form' => { invalid: true }.to_json
          }
        }
      )
    end

    context 'HCA tests' do
      let(:test_veteran) do
        File.read(
          Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json')
        )
      end

      it 'supports getting the hca health check' do
        VCR.use_cassette('hca/health_check', match_requests_on: [:body]) do
          expect(subject).to validate(
            :get,
            '/v0/health_care_applications/healthcheck',
            200
          )
        end
      end

      it 'supports submitting a health care application', run_at: '2017-01-31' do
        VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
          expect(subject).to validate(
            :post,
            '/v0/health_care_applications',
            200,
            '_data' => {
              'form' => test_veteran
            }
          )
        end

        expect(subject).to validate(
          :post,
          '/v0/health_care_applications',
          422,
          '_data' => {
            'form' => {}.to_json
          }
        )

        allow_any_instance_of(HCA::Service).to receive(:post) do
          raise Common::Client::Errors::HTTPError, 'error message'
        end

        expect(subject).to validate(
          :post,
          '/v0/health_care_applications',
          400,
          '_data' => {
            'form' => test_veteran
          }
        )
      end
    end

    describe 'rx tests' do
      include Rx::ClientHelpers

      before(:each) do
        allow(Rx::Client).to receive(:new).and_return(authenticated_client)
        use_authenticated_current_user(current_user: mhv_user)
      end

      context 'successful calls' do
        it 'supports getting a list of all prescriptions' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
            expect(subject).to validate(:get, '/v0/prescriptions', 200)
          end
        end

        it 'supports getting a list of active prescriptions' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions') do
            expect(subject).to validate(:get, '/v0/prescriptions/active', 200)
          end
        end

        it 'supports getting details of a particular prescription' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
            expect(subject).to validate(:get, '/v0/prescriptions/{id}', 200, 'id' => '13650545')
          end
        end

        it 'supports refilling a prescription' do
          VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
            expect(subject).to validate(:patch, '/v0/prescriptions/{id}/refill', 204, 'id' => '13650545')
          end
        end

        it 'supports tracking a prescription' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_for_a_prescription') do
            expect(subject).to validate(
              :get, '/v0/prescriptions/{prescription_id}/trackings', 200, 'prescription_id' => '13650541'
            )
          end
        end
      end

      context 'unsucessful calls' do
        it 'returns error on showing a prescription with bad id' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
            expect(subject).to validate(:get, '/v0/prescriptions/{id}', 404, 'id' => '1')
          end
        end

        it 'returns error on refilling a prescription with bad id' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/prescription_refill_error') do
            expect(subject).to validate(:patch, '/v0/prescriptions/{id}/refill', 400, 'id' => '1')
          end
        end

        it 'returns an error tracking a prescription with a bad id' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/tracking_error_id') do
            expect(subject).to validate(
              :get, '/v0/prescriptions/{prescription_id}/trackings', 400, 'prescription_id' => '1'
            )
          end
        end
      end
    end

    describe 'messaging tests' do
      include SM::ClientHelpers

      let(:uploads) do
        [
          Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file1.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file2.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file3.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file4.jpg', 'image/jpg')
        ]
      end

      before(:each) do
        allow(SM::Client).to receive(:new).and_return(authenticated_client)
        use_authenticated_current_user(current_user: mhv_user)
      end

      describe 'triage teams' do
        context 'successful calls' do
          it 'supports getting a list of all prescriptions' do
            VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
              expect(subject).to validate(:get, '/v0/messaging/health/recipients', 200)
            end
          end
        end
      end

      describe 'folders' do
        context 'successful calls' do
          it 'supports getting a list of all folders' do
            VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
              expect(subject).to validate(:get, '/v0/messaging/health/folders', 200)
            end
          end

          it 'supports getting a list of all messages in a folder' do
            VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
              expect(subject).to validate(
                :get,
                '/v0/messaging/health/folders/{folder_id}/messages', 200, 'folder_id' => '0'
              )
            end
          end

          it 'supports getting information about a specific folder' do
            VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
              expect(subject).to validate(:get, '/v0/messaging/health/folders/{id}', 200, 'id' => '0')
            end
          end

          it 'supports creating a new folder' do
            VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
              expect(subject).to validate(:post, '/v0/messaging/health/folders',
                                          201, '_data' => { 'folder' => { 'name' => 'test folder 66745' } })
            end
          end

          it 'supports deleting a folder' do
            VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
              expect(subject).to validate(:delete, '/v0/messaging/health/folders/{id}', 204, 'id' => '674886')
            end
          end
        end

        context 'unsuccessful calls' do
          it 'supports folder error messages' do
            VCR.use_cassette('sm_client/folders/gets_a_single_folder_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/folders/{id}', 400, 'id' => '1000')
            end
          end

          it 'supports folder error messages' do
            VCR.use_cassette('sm_client/folders/deletes_a_folder_id_error') do
              expect(subject).to validate(:delete, '/v0/messaging/health/folders/{id}', 400, 'id' => '1000')
            end
          end

          it 'supports folder messages index error in a folder' do
            VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages_id_error') do
              expect(subject).to validate(
                :get,
                '/v0/messaging/health/folders/{folder_id}/messages', 400, 'folder_id' => '1000'
              )
            end
          end
        end
      end

      describe 'messages' do
        context 'successful calls' do
          it 'supports getting a list of all messages in a thread' do
            VCR.use_cassette('sm_client/messages/gets_a_message_thread') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}/thread', 200, 'id' => '573059')
            end
          end

          it 'supports getting a message' do
            VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}', 200, 'id' => '573059')
            end
          end

          it 'supports getting a list of message categories' do
            VCR.use_cassette('sm_client/messages/gets_message_categories') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/categories', 200)
            end
          end

          it 'supports getting message attachments' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          200, 'message_id' => '629999', 'id' => '629993')
            end
          end

          it 'supports moving a message to another folder' do
            VCR.use_cassette('sm_client/messages/moves_a_message_with_id') do
              expect(subject).to validate(:patch, '/v0/messaging/health/messages/{id}/move',
                                          204, 'id' => '573052', '_query_string' => 'folder_id=0')
            end
          end

          it 'supports creating a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 200,
                '_data' => { 'message' => {
                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                  'body' => 'Continuous Integration'
                } }
              )
            end
          end

          it 'supports creating a message with attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 200,
                'id' => '674838',
                '_data' => {
                  'message' => {
                    'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                    'body' => 'Continuous Integration'
                  },
                  'uploads' => uploads
                }
              )
            end
          end

          it 'supports replying to a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages/{id}/reply', 201,
                'id' => '674838',
                '_data' => { 'message' => {
                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                  'body' => 'Continuous Integration'
                } }
              )
            end
          end

          it 'supports replying to a message with attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages/{id}/reply', 201,
                'id' => '674838',
                '_data' => {
                  'message' => {
                    'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                    'body' => 'Continuous Integration'
                  },
                  'uploads' => uploads
                }
              )
            end
          end

          it 'supports deleting a message' do
            VCR.use_cassette('sm_client/messages/deletes_the_message_with_id') do
              expect(subject).to validate(:delete, '/v0/messaging/health/messages/{id}', 204, 'id' => '573052')
            end
          end
        end

        context 'unsuccessful calls' do
          it 'supports errors for list of all messages in a thread with invalid id' do
            VCR.use_cassette('sm_client/messages/gets_a_message_thread_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}/thread', 400, 'id' => '999999')
            end
          end

          it 'supports error message with invalid id' do
            VCR.use_cassette('sm_client/messages/gets_a_message_with_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}', 400, 'id' => '999999')
            end
          end

          it 'supports errors getting message attachments with invalid message id' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment_message_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          400, 'message_id' => '999999', 'id' => '629993')
            end
          end

          it 'supports errors getting message attachments with invalid attachment id' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment_attachment_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          400, 'message_id' => '629999', 'id' => '999999')
            end
          end

          it 'supports errors moving a message to another folder' do
            VCR.use_cassette('sm_client/messages/moves_a_message_with_id_error') do
              expect(subject).to validate(:patch, '/v0/messaging/health/messages/{id}/move',
                                          400, 'id' => '999999', '_query_string' => 'folder_id=0')
            end
          end

          it 'supports errors creating a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments_recipient_id_error') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 400,
                '_data' => { 'message' => {
                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '1',
                  'body' => 'Continuous Integration'
                } }
              )
            end
          end

          it 'supports errors replying to a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments_id_error') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages/{id}/reply', 400,
                'id' => '999999',
                '_data' => { 'message' => {
                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                  'body' => 'Continuous Integration'
                } }
              )
            end
          end

          it 'supports errors deleting a message' do
            VCR.use_cassette('sm_client/messages/deletes_the_message_with_id_error') do
              expect(subject).to validate(:delete, '/v0/messaging/health/messages/{id}', 400, 'id' => '999999')
            end
          end
        end
      end

      describe 'message drafts' do
        context 'successful calls' do
          it 'supports creating a message draft' do
            VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/message_drafts', 201,
                '_data' => { 'message_draft' => {
                  'subject' => 'Subject 1', 'category' => 'OTHER', 'recipient_id' => '613586',
                  'body' => 'Body 1'
                } }
              )
            end
          end

          [:put, :patch].each do |op|
            it "supports updating a message draft with #{op}" do
              VCR.use_cassette('sm_client/message_drafts/updates_a_draft') do
                expect(subject).to validate(
                  op, '/v0/messaging/health/message_drafts/{id}', 204,
                  'id' => '674942',
                  '_data' => { 'message_draft' => {
                    'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                    'body' => 'Updated Body'
                  } }
                )
              end
            end
          end

          it 'supports creating a message draft reply' do
            VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/message_drafts/{reply_id}/replydraft', 201,
                'reply_id' => '674874',
                '_data' => { 'message_draft' => {
                  'subject' => 'Updated Subject', 'category' => 'OTHER', 'recipient_id' => '613586',
                  'body' => 'Body 1'
                } }
              )
            end
          end

          it 'supports updating a message draft reply' do
            VCR.use_cassette('sm_client/message_drafts/updates_a_draft_reply') do
              expect(subject).to validate(
                :put, '/v0/messaging/health/message_drafts/{reply_id}/replydraft/{draft_id}', 204,
                'reply_id' => '674874',
                'draft_id' => '674944',
                '_data' => { 'message_draft' => {
                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                  'body' => 'Updated Body'
                } }
              )
            end
          end
        end
      end
    end

    it 'supports getting the user data' do
      expect(subject).to validate(:get, '/v0/user', 200, auth_options)
      expect(subject).to validate(:get, '/v0/user', 401)
    end

    context 'terms and conditions routes' do
      context 'with some terms and acceptances' do
        let!(:terms) { create(:terms_and_conditions, latest: true) }
        # The Faker in the factory will _sometimes_ return the same name. make sure it's different
        # so that the association in terms_acc works as expected with these tests.
        let!(:terms2) { create(:terms_and_conditions, latest: true, name: "#{terms.name}-again") }
        let!(:terms_acc) do
          create(:terms_and_conditions_acceptance, user_uuid: mhv_user.uuid, terms_and_conditions: terms)
        end

        it 'validates the routes' do
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions',
            200,
            auth_options
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest',
            200,
            auth_options.merge('name' => terms.name)
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            200,
            auth_options.merge('name' => terms.name)
          )
          expect(subject).to validate(
            :post,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            422,
            auth_options.merge('name' => terms.name)
          )
          expect(subject).to validate(
            :post,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            200,
            auth_options.merge('name' => terms2.name)
          )
        end

        it 'validates auth errors' do
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions',
            401
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest',
            401,
            'name' => terms.name
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            401,
            'name' => terms.name
          )
          expect(subject).to validate(
            :post,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            401,
            'name' => terms.name
          )
        end
      end

      context 'with no terms and acceptances' do
        it 'validates the routes' do
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions',
            200,
            auth_options
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest',
            404,
            auth_options.merge('name' => 'blat')
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            404,
            auth_options.merge('name' => 'blat')
          )
          expect(subject).to validate(
            :post,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            404,
            auth_options.merge('name' => 'blat')
          )
        end
      end
    end
  end

  context 'and' do
    it 'tests all documented routes' do
      expect(subject).to validate_all_paths
    end
  end
end
