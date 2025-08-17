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

RSpec.describe 'the v0 API documentation (Part 4)', order: :defined, type: %i[apivore request] do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob') }

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid)
    end

    describe 'appeals' do
      it 'documents appeals 401' do
        expect(subject).to validate(:get, '/v0/appeals', 401)
      end

      it 'documents appeals 200' do
        VCR.use_cassette('/caseflow/appeals') do
          expect(subject).to validate(:get, '/v0/appeals', 200, headers)
        end
      end

      it 'documents appeals 403' do
        VCR.use_cassette('/caseflow/forbidden') do
          expect(subject).to validate(:get, '/v0/appeals', 403, headers)
        end
      end

      it 'documents appeals 404' do
        VCR.use_cassette('/caseflow/not_found') do
          expect(subject).to validate(:get, '/v0/appeals', 404, headers)
        end
      end

      it 'documents appeals 422' do
        VCR.use_cassette('/caseflow/invalid_ssn') do
          expect(subject).to validate(:get, '/v0/appeals', 422, headers)
        end
      end

      it 'documents appeals 502' do
        VCR.use_cassette('/caseflow/server_error') do
          expect(subject).to validate(:get, '/v0/appeals', 502, headers)
        end
      end
    end

    describe 'appointments' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
      end

      context 'when successful' do
        it 'supports getting appointments data' do
          VCR.use_cassette('ihub/appointments/simple_success') do
            expect(subject).to validate(:get, '/v0/appointments', 200, headers)
          end
        end
      end

      context 'when not signed in' do
        it 'returns a 401 with error details' do
          expect(subject).to validate(:get, '/v0/appointments', 401)
        end
      end

      context 'when iHub experiences an error' do
        it 'returns a 400 with error details' do
          VCR.use_cassette('ihub/appointments/error_occurred') do
            expect(subject).to validate(:get, '/v0/appointments', 400, headers)
          end
        end
      end

      context 'the user does not have an ICN' do
        before do
          allow_any_instance_of(User).to receive(:icn).and_return(nil)
        end

        it 'returns a 502 with error details' do
          expect(subject).to validate(:get, '/v0/appointments', 502, headers)
        end
      end
    end

    describe 'Direct Deposit' do
      let(:user) { create(:user, :loa3, :accountable, icn: '1012666073V986297') }

      before do
        token = 'abcdefghijklmnop'
        allow_any_instance_of(DirectDeposit::Configuration).to receive(:access_token).and_return(token)
      end

      context 'GET' do
        it 'returns a 200' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
            expect(subject).to validate(:get, '/v0/profile/direct_deposits', 200, headers)
          end
        end

        it 'returns a 400' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          VCR.use_cassette('lighthouse/direct_deposit/show/errors/400_invalid_icn') do
            expect(subject).to validate(:get, '/v0/profile/direct_deposits', 400, headers)
          end
        end

        it 'returns a 401' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          VCR.use_cassette('lighthouse/direct_deposit/show/errors/401_invalid_token') do
            expect(subject).to validate(:get, '/v0/profile/direct_deposits', 401, headers)
          end
        end

        it 'returns a 404' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          VCR.use_cassette('lighthouse/direct_deposit/show/errors/404_response') do
            expect(subject).to validate(:get, '/v0/profile/direct_deposits', 404, headers)
          end
        end
      end

      context 'PUT' do
        it 'returns a 200' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          params = {
            payment_account: { account_number: '1234567890', account_type: 'Checking', routing_number: '031000503' }
          }
          VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
            expect(subject).to validate(:put,
                                        '/v0/profile/direct_deposits',
                                        200,
                                        headers.merge('_data' => params))
          end
        end

        it 'returns a 400' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          params = {
            payment_account: { account_number: '1234567890', account_type: 'Checking', routing_number: '031000503' }
          }
          VCR.use_cassette('lighthouse/direct_deposit/update/400_routing_number_fraud') do
            expect(subject).to validate(:put,
                                        '/v0/profile/direct_deposits',
                                        400,
                                        headers.merge('_data' => params))
          end
        end
      end
    end

    describe 'onsite notifications' do
      let(:private_key) { OpenSSL::PKey::EC.new(File.read('spec/support/certificates/notification-private.pem')) }

      before do
        allow_any_instance_of(V0::OnsiteNotificationsController).to receive(:public_key).and_return(
          OpenSSL::PKey::EC.new(
            File.read('spec/support/certificates/notification-public.pem')
          )
        )
      end

      it 'supports onsite_notifications #index' do
        create(:onsite_notification, va_profile_id: mhv_user.vet360_id)
        expect(subject).to validate(:get, '/v0/onsite_notifications', 401)

        expect(subject).to validate(:get, '/v0/onsite_notifications', 200, headers)
      end

      it 'supports updating onsite notifications' do
        expect(subject).to validate(
          :patch,
          '/v0/onsite_notifications/{id}',
          401,
          'id' => '1'
        )

        onsite_notification = create(:onsite_notification, va_profile_id: mhv_user.vet360_id)

        expect(subject).to validate(
          :patch,
          '/v0/onsite_notifications/{id}',
          404,
          headers.merge(
            'id' => onsite_notification.id + 1
          )
        )

        expect(subject).to validate(
          :patch,
          '/v0/onsite_notifications/{id}',
          200,
          headers.merge(
            'id' => onsite_notification.id,
            '_data' => {
              onsite_notification: {
                dismissed: true
              }
            }
          )
        )

        # rubocop:disable Rails/SkipsModelValidations
        onsite_notification.update_column(:template_id, '1')
        # rubocop:enable Rails/SkipsModelValidations
        expect(subject).to validate(
          :patch,
          '/v0/onsite_notifications/{id}',
          422,
          headers.merge(
            'id' => onsite_notification.id,
            '_data' => {
              onsite_notification: {
                dismissed: true
              }
            }
          )
        )
      end

      it 'supports creating onsite notifications' do
        expect(subject).to validate(:post, '/v0/onsite_notifications', 403)

        payload = { user: 'va_notify', iat: Time.current.to_i, exp: 1.minute.from_now.to_i }
        expect(subject).to validate(
          :post,
          '/v0/onsite_notifications',
          200,
          '_headers' => {
            'Authorization' => "Bearer #{JWT.encode(payload, private_key, 'ES256')}"
          },
          '_data' => {
            onsite_notification: {
              template_id: 'f9947b27-df3b-4b09-875c-7f76594d766d',
              va_profile_id: '1'
            }
          }
        )

        payload = { user: 'va_notify', iat: Time.current.to_i, exp: 1.minute.from_now.to_i }
        expect(subject).to validate(
          :post,
          '/v0/onsite_notifications',
          422,
          '_headers' => {
            'Authorization' => "Bearer #{JWT.encode(payload, private_key, 'ES256')}"
          },
          '_data' => {
            onsite_notification: {
              template_id: '1',
              va_profile_id: '1'
            }
          }
        )
      end
    end

    describe 'profiles', :skip_va_profile_user do
      let(:mhv_user) { create(:user, :loa3, idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }

      it 'supports getting service history data' do
        expect(subject).to validate(:get, '/v0/profile/service_history', 401)
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          expect(subject).to validate(:get, '/v0/profile/service_history', 200, headers)
        end
      end

      it 'supports getting personal information data' do
        expect(subject).to validate(:get, '/v0/profile/personal_information', 401)
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('va_profile/demographics/demographics') do
            expect(subject).to validate(:get, '/v0/profile/personal_information', 200, headers)
          end
        end
      end

      it 'supports getting full name data' do
        expect(subject).to validate(:get, '/v0/profile/full_name', 401)

        user = build(:user, :loa3, middle_name: 'Robert')
        headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }

        expect(subject).to validate(:get, '/v0/profile/full_name', 200, headers)
      end

      it 'supports updating a va profile email' do
        expect(subject).to validate(:post, '/v0/profile/email_addresses/create_or_update', 401)

        VCR.use_cassette('va_profile/contact_information/put_email_success') do
          email_address = build(:email)

          expect(subject).to validate(
            :post,
            '/v0/profile/email_addresses/create_or_update',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports posting va_profile email address data' do
        expect(subject).to validate(:post, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('va_profile/contact_information/post_email_success') do
          email_address = build(:email)

          expect(subject).to validate(
            :post,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports putting va_profile email address data' do
        expect(subject).to validate(:put, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('va_profile/contact_information/put_email_success') do
          email_address = build(:email, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports deleting va_profile email address data' do
        expect(subject).to validate(:delete, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('va_profile/contact_information/delete_email_success') do
          email_address = build(:email, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports updating va_profile telephone data' do
        expect(subject).to validate(:post, '/v0/profile/telephones/create_or_update', 401)

        VCR.use_cassette('va_profile/contact_information/put_telephone_success') do
          telephone = build(:telephone)

          expect(subject).to validate(
            :post,
            '/v0/profile/telephones/create_or_update',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports posting va_profile telephone data' do
        expect(subject).to validate(:post, '/v0/profile/telephones', 401)

        VCR.use_cassette('va_profile/contact_information/post_telephone_success') do
          telephone = build(:telephone)

          expect(subject).to validate(
            :post,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports putting va_profile telephone data' do
        expect(subject).to validate(:put, '/v0/profile/telephones', 401)

        VCR.use_cassette('va_profile/contact_information/put_telephone_success') do
          telephone = build(:telephone, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports deleting va_profile telephone data' do
        expect(subject).to validate(:delete, '/v0/profile/telephones', 401)

        VCR.use_cassette('va_profile/contact_information/delete_telephone_success') do
          telephone = build(:telephone, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports putting va_profile preferred-name data' do
        expect(subject).to validate(:put, '/v0/profile/preferred_names', 401)

        VCR.use_cassette('va_profile/demographics/post_preferred_name_success') do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')

          expect(subject).to validate(
            :put,
            '/v0/profile/preferred_names',
            200,
            headers.merge('_data' => preferred_name.as_json)
          )
        end
      end

      it 'supports putting va_profile gender-identity data' do
        expect(subject).to validate(:put, '/v0/profile/gender_identities', 401)

        VCR.use_cassette('va_profile/demographics/post_gender_identity_success') do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          expect(subject).to validate(
            :put,
            '/v0/profile/gender_identities',
            200,
            headers.merge('_data' => gender_identity.as_json)
          )
        end
      end

      context 'communication preferences' do
        before do
          allow_any_instance_of(User).to receive(:vet360_id).and_return('18277')

          headers['_headers'].merge!(
            'accept' => 'application/json',
            'content-type' => 'application/json'
          )
        end

        let(:valid_params) do
          {
            communication_item: {
              id: 2,
              communication_channel: {
                id: 1,
                communication_permission: {
                  allowed: true
                }
              }
            }
          }
        end

        it 'supports the communication preferences update response', run_at: '2021-03-24T23:46:17Z' do
          path = '/v0/profile/communication_preferences/{communication_permission_id}'
          expect(subject).to validate(:patch, path, 401, 'communication_permission_id' => 1)

          VCR.use_cassette('va_profile/communication/put_communication_permissions', VCR::MATCH_EVERYTHING) do
            expect(subject).to validate(
              :patch,
              path,
              200,
              headers.merge(
                '_data' => valid_params.to_json,
                'communication_permission_id' => 46
              )
            )
          end
        end

        it 'supports the communication preferences create response', run_at: '2021-03-24T22:38:21Z' do
          valid_params[:communication_item][:communication_channel][:communication_permission][:allowed] = false
          path = '/v0/profile/communication_preferences'
          expect(subject).to validate(:post, path, 401)

          VCR.use_cassette('va_profile/communication/post_communication_permissions', VCR::MATCH_EVERYTHING) do
            expect(subject).to validate(
              :post,
              path,
              200,
              headers.merge(
                '_data' => valid_params.to_json
              )
            )
          end
        end

        it 'supports the communication preferences index response' do
          path = '/v0/profile/communication_preferences'
          expect(subject).to validate(:get, path, 401)

          VCR.use_cassette('va_profile/communication/get_communication_permissions', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/communication/communication_items', VCR::MATCH_EVERYTHING) do
              expect(subject).to validate(
                :get,
                path,
                200,
                headers
              )
            end
          end
        end
      end
    end
  end
end