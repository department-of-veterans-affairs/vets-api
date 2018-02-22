# frozen_string_literal: true

require 'rails_helper'

require 'saml/settings_service'

require 'sm/client'
require 'support/sm_client_helpers'

require 'rx/client'
require 'support/rx_client_helpers'

require 'bb/client'
require 'support/bb_client_helpers'

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
                          accessible?: true)
  end
  let(:mhv_user) { build(:user, :mhv) }

  before do
    Session.create(uuid: mhv_user.uuid, token: token)
    User.create(mhv_user)
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    allow(SAML::SettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
  end

  context 'has valid paths' do
    let(:auth_options) { { '_headers' => { 'Authorization' => "Token token=#{token}" } } }

    it 'supports fetching authentication urls' do
      expect(subject).to validate(:get, '/v0/sessions/authn_urls', 200)
    end

    it 'supports invoking multifactor policy' do
      expect(subject).to validate(:get, '/v0/sessions/multifactor', 200, auth_options)
      expect(subject).to validate(:get, '/v0/sessions/multifactor', 401)
    end

    it 'supports fetching identity verification url' do
      expect(subject).to validate(:get, '/v0/sessions/identity_proof', 200, auth_options)
      expect(subject).to validate(:get, '/v0/sessions/identity_proof', 401)
    end

    it 'supports session deletion' do
      expect(subject).to validate(:delete, '/v0/sessions', 202, auth_options)
      expect(subject).to validate(:delete, '/v0/sessions', 401)
    end

    it 'supports listing in-progress forms' do
      expect(subject).to validate(:get, '/v0/in_progress_forms', 200, auth_options)
      expect(subject).to validate(:get, '/v0/in_progress_forms', 401)
    end

    it 'supports fetching maintenance windows' do
      expect(subject).to validate(:get, '/v0/maintenance_windows', 200)
    end

    it 'supports getting an in-progress form' do
      FactoryBot.create(:in_progress_form, user_uuid: mhv_user.uuid)
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
      form = FactoryBot.create(:in_progress_form, user_uuid: mhv_user.uuid)
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
            'form' => build(:va1990).form
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
          VCR.use_cassette('rx_client/prescriptions/prescription_refill_error') do
            expect(subject).to validate(:patch, '/v0/prescriptions/{id}/refill', 404, 'id' => '1')
          end
        end

        it 'returns error on refilling a prescription that is not refillable' do
          VCR.use_cassette('rx_client/prescriptions/prescription_not_refillable_error') do
            expect(subject).to validate(:patch, '/v0/prescriptions/{id}/refill', 400, 'id' => '1')
          end
        end

        it 'returns an error tracking a prescription with a bad id' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/tracking_error_id') do
            expect(subject).to validate(
              :get, '/v0/prescriptions/{prescription_id}/trackings', 404, 'prescription_id' => '1'
            )
          end
        end
      end
    end

    describe 'secure messaging' do
      include SM::ClientHelpers

      let(:uploads) do
        [
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file2.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file3.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file4.jpg', 'image/jpg')
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
              expect(subject).to validate(:get, '/v0/messaging/health/folders/{id}', 404, 'id' => '1000')
            end
          end

          it 'supports folder error messages' do
            VCR.use_cassette('sm_client/folders/deletes_a_folder_id_error') do
              expect(subject).to validate(:delete, '/v0/messaging/health/folders/{id}', 404, 'id' => '1000')
            end
          end

          it 'supports folder messages index error in a folder' do
            VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages_id_error') do
              expect(subject).to validate(
                :get,
                '/v0/messaging/health/folders/{folder_id}/messages', 404, 'folder_id' => '1000'
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
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}/thread', 404, 'id' => '999999')
            end
          end

          it 'supports error message with invalid id' do
            VCR.use_cassette('sm_client/messages/gets_a_message_with_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}', 404, 'id' => '999999')
            end
          end

          it 'supports errors getting message attachments with invalid message id' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment_message_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          404, 'message_id' => '999999', 'id' => '629993')
            end
          end

          it 'supports errors getting message attachments with invalid attachment id' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment_attachment_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          404, 'message_id' => '629999', 'id' => '999999')
            end
          end

          it 'supports errors moving a message to another folder' do
            VCR.use_cassette('sm_client/messages/moves_a_message_with_id_error') do
              expect(subject).to validate(:patch, '/v0/messaging/health/messages/{id}/move',
                                          404, 'id' => '999999', '_query_string' => 'folder_id=0')
            end
          end

          it 'supports errors creating a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments_recipient_id_error') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 422,
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
                :post, '/v0/messaging/health/messages/{id}/reply', 404,
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
              expect(subject).to validate(:delete, '/v0/messaging/health/messages/{id}', 404, 'id' => '999999')
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

          %i[put patch].each do |op|
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

    describe 'bb' do
      include BB::ClientHelpers

      describe 'health_records' do
        before(:each) do
          allow_any_instance_of(ApplicationController).to receive(:authenticate_token).and_return(true)
          allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(mhv_user)

          allow(BB::Client).to receive(:new).and_return(authenticated_client)
        end

        describe 'show a report' do
          context 'successful calls' do
            it 'supports showing a report' do
              # Using mucked-up yml because apivore has a problem processing non-json responses
              VCR.use_cassette('bb_client/gets_a_text_report_for_apivore') do
                expect(subject).to validate(:get, '/v0/health_records', 200, '_query_string' => 'doc_type=txt')
              end
            end
          end

          context 'unsuccessful calls' do
            it 'handles a backend error' do
              VCR.use_cassette('bb_client/report_error_response') do
                expect(subject).to validate(:get, '/v0/health_records', 503, '_query_string' => 'doc_type=txt')
              end
            end
          end
        end

        describe 'create a report' do
          context 'successful calls' do
            it 'supports creating a report' do
              VCR.use_cassette('bb_client/generates_a_report') do
                expect(subject).to validate(
                  :post, '/v0/health_records', 202,
                  '_data' => {
                    'from_date' => 10.years.ago.iso8601.to_json,
                    'to_date' => Time.now.iso8601.to_json,
                    'data_classes' => BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES.to_json
                  }
                )
              end
            end
          end

          context 'unsuccessful calls' do
            it 'requires from_date, to_date, and data_classes' do
              expect(subject).to validate(
                :post, '/v0/health_records', 422,
                '_data' => {
                  'to_date' => Time.now.iso8601.to_json,
                  'data_classes' => BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES.to_json
                }
              )

              expect(subject).to validate(
                :post, '/v0/health_records', 422,
                '_data' => {
                  'from_date' => 10.years.ago.iso8601.to_json,
                  'data_classes' => BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES.to_json
                }
              )

              expect(subject).to validate(
                :post, '/v0/health_records', 422,
                '_data' => {
                  'from_date' => 10.years.ago.iso8601.to_json,
                  'to_date' => Time.now.iso8601.to_json
                }
              )
            end
          end
        end

        describe 'eligible data classes' do
          it 'supports retrieving eligible data classes' do
            VCR.use_cassette('bb_client/gets_a_list_of_eligible_data_classes') do
              expect(subject).to validate(:get, '/v0/health_records/eligible_data_classes', 200)
            end
          end
        end

        describe 'refresh' do
          context 'successful calls' do
            it 'supports health records refresh' do
              VCR.use_cassette('bb_client/gets_a_list_of_extract_statuses') do
                expect(subject).to validate(:get, '/v0/health_records/refresh', 200)
              end
            end
          end

          context 'unsuccessful calls' do
            let(:mhv_account) do
              double('mhv_account', eligible?: true, needs_terms_acceptance?: false, accessible?: false)
            end

            it 'raises forbidden when user is not eligible' do
              expect(subject).to validate(:get, '/v0/health_records/refresh', 403)
            end
          end
        end
      end
    end

    describe 'gibct' do
      describe 'institutions' do
        describe 'autocomplete' do
          it 'supports autocomplete of institution names' do
            VCR.use_cassette('gi_client/gets_a_list_of_autocomplete_suggestions') do
              expect(subject).to validate(
                :get, '/v0/gi/institutions/autocomplete', 200, '_query_string' => 'term=university'
              )
            end
          end
        end

        describe 'search' do
          it 'supports autocomplete of institution names' do
            VCR.use_cassette('gi_client/gets_search_results') do
              expect(subject).to validate(
                :get, '/v0/gi/institutions/search', 200, '_query_string' => 'name=illinois'
              )
            end
          end
        end

        describe 'show' do
          context 'successful calls' do
            it 'supports showing institution details' do
              VCR.use_cassette('gi_client/gets_the_institution_details') do
                expect(subject).to validate(:get, '/v0/gi/institutions/{id}', 200, 'id' => '20603613')
              end
            end
          end

          context 'unsuccessful calls' do
            it 'returns error on refilling a prescription with bad id' do
              VCR.use_cassette('gi_client/gets_institution_details_error') do
                expect(subject).to validate(:get, '/v0/gi/institutions/{id}', 404, 'id' => 'splunge')
              end
            end
          end
        end
      end

      describe 'calculator_constants' do
        it 'supports getting all calculator constants' do
          VCR.use_cassette('gi_client/gets_the_calculator_constants') do
            expect(subject).to validate(
              :get, '/v0/gi/calculator_constants', 200
            )
          end
        end
      end
    end

    context 'without EVSS mock' do
      before { Settings.evss.mock_gi_bill_status = false }
      before { Settings.evss.mock_letters = false }

      it 'supports getting EVSS Gi Bill Status' do
        expect(subject).to validate(:get, '/v0/post911_gi_bill_status', 401)
        VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
          # TODO: this cassette was hacked to return all 3 entitlements since
          # I cannot make swagger doc allow an attr to be :object or :null
          expect(subject).to validate(:get, '/v0/post911_gi_bill_status', 200, auth_options)
        end
        VCR.use_cassette('evss/gi_bill_status/vet_not_found') do
          expect(subject).to validate(:get, '/v0/post911_gi_bill_status', 404, auth_options)
        end
      end

      it 'supports getting EVSS Letters' do
        expect(subject).to validate(:get, '/v0/letters', 401)
        VCR.use_cassette('evss/letters/letters') do
          expect(subject).to validate(:get, '/v0/letters', 200, auth_options)
        end
      end

      it 'supports getting EVSS Letters Beneficiary' do
        expect(subject).to validate(:get, '/v0/letters/beneficiary', 401)
        VCR.use_cassette('evss/letters/beneficiary') do
          expect(subject).to validate(:get, '/v0/letters/beneficiary', 200, auth_options)
        end
      end

      it 'supports posting EVSS Letters' do
        expect(subject).to validate(:post, '/v0/letters/{id}', 401, 'id' => 'commissary')
      end

      it 'supports getting EVSS PCIUAddress states' do
        expect(subject).to validate(:get, '/v0/address/states', 401)
        VCR.use_cassette('evss/pciu_address/states') do
          expect(subject).to validate(:get, '/v0/address/states', 200, auth_options)
        end
      end

      it 'supports getting EVSS PCIUAddress countries' do
        expect(subject).to validate(:get, '/v0/address/countries', 401)
        VCR.use_cassette('evss/pciu_address/countries') do
          expect(subject).to validate(:get, '/v0/address/countries', 200, auth_options)
        end
      end

      it 'supports getting EVSS PCIUAddress' do
        expect(subject).to validate(:get, '/v0/address', 401)
        VCR.use_cassette('evss/pciu_address/address_domestic') do
          expect(subject).to validate(:get, '/v0/address', 200, auth_options)
        end
      end

      it 'supports putting EVSS PCIUAddress' do
        expect(subject).to validate(:put, '/v0/address', 401)
        VCR.use_cassette('evss/pciu_address/address_update') do
          expect(subject).to validate(
            :put,
            '/v0/address',
            200,
            auth_options.update(
              '_data' => {
                'type' => 'DOMESTIC',
                'address_effective_date' => '2017-08-07T19:43:59.383Z',
                'address_one' => '225 5th St',
                'address_two' => '',
                'address_three' => '',
                'city' => 'Springfield',
                'state_code' => 'OR',
                'country_name' => 'USA',
                'zip_code' => '97477',
                'zip_suffix' => ''
              }
            )
          )
        end
      end
    end

    it 'supports getting the user data' do
      expect(subject).to validate(:get, '/v0/user', 200, auth_options)
      expect(subject).to validate(:get, '/v0/user', 401)
    end

    context '#feedback' do
      before(:all) do
        Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.current)
      end
      before(:each) do
        Rack::Attack.cache.store.flushdb
      end
      let(:feedback_params) do
        {
          'description' => 'I liked this page',
          'target_page' => '/some/example/page.html',
          'owner_email' => 'example@email.com'
        }
      end
      let(:missing_feedback_params) { feedback_params.except('target_page') }

      it 'returns 202 for valid feedback' do
        expect(subject).to validate(:post, '/v0/feedback', 202,
                                    '_data' => { 'feedback' => feedback_params })
      end
      it 'returns 400 if a param is missing or invalid' do
        expect(subject).to validate(:post, '/v0/feedback', 400,
                                    '_data' => { 'feedback' => missing_feedback_params })
      end
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

    describe 'facility locator tests' do
      context 'successful calls' do
        it 'supports getting a list of facilities' do
          VCR.use_cassette('facilities/va/pdx_bbox') do
            expect(subject).to validate(:get, '/v0/facilities/va', 200,
                                        'bbox' => ['-122.440689', '45.451913', '-122.78675', '45.64'])
          end
        end

        it 'supports getting a list of facilities' do
          VCR.use_cassette('facilities/va/vha_648A4') do
            expect(subject).to validate(:get, '/v0/facilities/va/{id}', 200, 'id' => 'vha_648A4')
          end
        end

        it '404s on non-existent facility' do
          VCR.use_cassette('facilities/va/nonexistent_cemetery') do
            expect(subject).to validate(:get, '/v0/facilities/va/{id}', 404, 'id' => 'nca_9999999')
          end
        end

        it '400s on invalid bounding box query' do
          expect(subject).to validate(:get, '/v0/facilities/va', 400,
                                      '_query_string' => 'bbox[]=-122&bbox[]=45&bbox[]=-123')
        end
      end
    end

    describe 'appeals' do
      it 'documents appeals 401' do
        expect(subject).to validate(:get, '/v0/appeals_v2', 401)
      end

      it 'documents appeals 200' do
        VCR.use_cassette('/appeals/appeals') do
          expect(subject).to validate(:get, '/v0/appeals_v2', 200, auth_options)
        end
      end

      it 'documents appeals 403' do
        VCR.use_cassette('/appeals/forbidden') do
          expect(subject).to validate(:get, '/v0/appeals_v2', 403, auth_options)
        end
      end

      it 'documents appeals 404' do
        VCR.use_cassette('/appeals/not_found') do
          expect(subject).to validate(:get, '/v0/appeals_v2', 404, auth_options)
        end
      end

      it 'documents appeals 422' do
        VCR.use_cassette('/appeals/invalid_ssn') do
          expect(subject).to validate(:get, '/v0/appeals_v2', 422, auth_options)
        end
      end

      it 'documents appeals 502' do
        VCR.use_cassette('/appeals/server_error') do
          expect(subject).to validate(:get, '/v0/appeals_v2', 502, auth_options)
        end
      end
    end
  end

  context 'and' do
    it 'tests all documented routes' do
      subject.untested_mappings.delete('/v0/letters/{id}') # exclude this route as it returns a binary
      expect(subject).to validate_all_paths
    end
  end
end
