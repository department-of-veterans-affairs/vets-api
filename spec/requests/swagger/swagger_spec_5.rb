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

RSpec.describe 'the v0 API documentation (Part 5)', order: :defined, type: %i[apivore request] do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob') }

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid)
    end

    describe 'profiles', :skip_va_profile_user do
      let(:mhv_user) { create(:user, :loa3, idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }

      it 'supports the address validation api' do
        address = build(:va_profile_address, :multiple_matches)
        VCR.use_cassette(
          'va_profile/address_validation/validate_match',
          VCR::MATCH_EVERYTHING
        ) do
          VCR.use_cassette(
            'va_profile/address_validation/candidate_multiple_matches',
            VCR::MATCH_EVERYTHING
          ) do
            expect(subject).to validate(
              :post,
              '/v0/profile/address_validation',
              200,
              headers.merge('_data' => { address: address.to_h })
            )
          end
        end
      end

      it 'supports va_profile create or update address api' do
        expect(subject).to validate(:post, '/v0/profile/addresses/create_or_update', 401)

        VCR.use_cassette('va_profile/contact_information/put_address_success') do
          address = build(:va_profile_address)

          expect(subject).to validate(
            :post,
            '/v0/profile/addresses/create_or_update',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports posting va_profile address data' do
        expect(subject).to validate(:post, '/v0/profile/addresses', 401)

        VCR.use_cassette('va_profile/contact_information/post_address_success') do
          address = build(:va_profile_address)

          expect(subject).to validate(
            :post,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports putting va_profile address data' do
        expect(subject).to validate(:put, '/v0/profile/addresses', 401)

        VCR.use_cassette('va_profile/contact_information/put_address_success') do
          address = build(:va_profile_address, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports deleting va_profile address data' do
        expect(subject).to validate(:delete, '/v0/profile/addresses', 401)

        VCR.use_cassette('va_profile/contact_information/delete_address_success') do
          address = build(:va_profile_address, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports updating va_profile permission data' do
        expect(subject).to validate(:post, '/v0/profile/permissions/create_or_update', 401)

        VCR.use_cassette('va_profile/contact_information/put_permission_success') do
          permission = build(:permission)

          expect(subject).to validate(
            :post,
            '/v0/profile/permissions/create_or_update',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports posting va_profile permission data' do
        expect(subject).to validate(:post, '/v0/profile/permissions', 401)

        VCR.use_cassette('va_profile/contact_information/post_permission_success') do
          permission = build(:permission)

          expect(subject).to validate(
            :post,
            '/v0/profile/permissions',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports putting va_profile permission data' do
        expect(subject).to validate(:put, '/v0/profile/permissions', 401)

        VCR.use_cassette('va_profile/contact_information/put_permission_success') do
          permission = build(:permission, id: 401)

          expect(subject).to validate(
            :put,
            '/v0/profile/permissions',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports deleting va_profile permission data' do
        expect(subject).to validate(:delete, '/v0/profile/permissions', 401)

        VCR.use_cassette('va_profile/contact_information/delete_permission_success') do
          permission = build(:permission, id: 361) # TODO: ID

          expect(subject).to validate(
            :delete,
            '/v0/profile/permissions',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports posting to initialize a vet360_id' do
        expect(subject).to validate(:post, '/v0/profile/initialize_vet360_id', 401)
        VCR.use_cassette('va_profile/person/init_vet360_id_success') do
          expect(subject).to validate(
            :post,
            '/v0/profile/initialize_vet360_id',
            200,
            headers.merge('_data' => {})
          )
        end
      end
    end

    describe 'profile/status', :skip_va_profile_user do
      before do
        allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)

        # vet360_id appears in the API request URI so we need it to match the cassette
        allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
          create(:find_profile_response, profile: build(:mpi_profile, vet360_id: '1'))
        )
      end

      let(:user) { build(:user, :loa3) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

      it 'supports GETting async transaction by ID' do
        transaction = create(
          :va_profile_address_transaction,
          transaction_id: 'a030185b-e88b-4e0d-a043-93e4f34c60d6',
          user_uuid: user.uuid
        )
        expect(subject).to validate(
          :get,
          '/v0/profile/status/{transaction_id}',
          401,
          'transaction_id' => transaction.transaction_id
        )

        VCR.use_cassette('va_profile/contact_information/address_transaction_status') do
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

        VCR.use_cassette('va_profile/contact_information/address_transaction_status') do
          expect(subject).to validate(
            :get,
            '/v0/profile/status/',
            200,
            headers
          )
        end
      end
    end

    describe 'profile/person/status/:transaction_id', :skip_va_profile_user do
      let(:user_without_vet360_id) { build(:user, :loa3) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user_without_vet360_id, nil, true) } } }

      before do
        allow_any_instance_of(User).to receive(:vet360_id).and_return(nil)
      end

      it 'supports GETting async person transaction by transaction ID' do
        transaction_id = '786efe0e-fd20-4da2-9019-0c00540dba4d'
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

        VCR.use_cassette('va_profile/contact_information/person_transaction_status') do
          expect(subject).to validate(
            :get,
            '/v0/profile/person/status/{transaction_id}',
            200,
            headers.merge('transaction_id' => transaction.transaction_id)
          )
        end
      end
    end

    describe 'contact information v2', :skip_vet360 do
      before do
        allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
        allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
      end

      describe 'profiles v2', :initiate_vaprofile, :skip_vet360 do
        let(:mhv_user) { build(:user, :loa3, idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }

        before do
          sign_in_as(mhv_user)
        end

        it 'supports getting service history data' do
          allow(Flipper).to receive(:enabled?).with(:profile_show_military_academy_attendance, nil).and_return(false)
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
          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            email_address = build(:email, :contact_info_v2)

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

          VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
            email_address = build(:email, :contact_info_v2)

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

          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
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

          VCR.use_cassette('va_profile/v2/contact_information/delete_email_success') do
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

          VCR.use_cassette('va_profile/v2/contact_information/put_telephone_success') do
            telephone = build(:telephone, :contact_info_v2)
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

          VCR.use_cassette('va_profile/v2/contact_information/post_telephone_success') do
            telephone = build(:telephone, :contact_info_v2)

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

          VCR.use_cassette('va_profile/v2/contact_information/put_telephone_success') do
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

          VCR.use_cassette('va_profile/v2/contact_information/delete_telephone_success') do
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

        it 'supports the address validation api' do
          allow(Flipper).to receive(:enabled?).with(:remove_pciu).and_return(true)
          address = build(:va_profile_v3_validation_address, :multiple_matches)
          VCR.use_cassette(
            'va_profile/address_validation/validate_match',
            VCR::MATCH_EVERYTHING
          ) do
            VCR.use_cassette(
              'va_profile/v3/address_validation/candidate_multiple_matches',
              VCR::MATCH_EVERYTHING
            ) do
              expect(subject).to validate(
                :post,
                '/v0/profile/address_validation',
                200,
                headers.merge('_data' => { address: address.to_h })
              )
            end
          end
        end

        it 'supports va_profile create or update address api' do
          expect(subject).to validate(:post, '/v0/profile/addresses/create_or_update', 401)
          VCR.use_cassette('va_profile/v2/contact_information/put_address_success') do
            address = build(:va_profile_v3_address, id: 15_035)

            expect(subject).to validate(
              :post,
              '/v0/profile/addresses/create_or_update',
              200,
              headers.merge('_data' => address.as_json)
            )
          end
        end

        it 'supports posting va_profile address data' do
          expect(subject).to validate(:post, '/v0/profile/addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/post_address_success') do
            address = build(:va_profile_v3_address)

            expect(subject).to validate(
              :post,
              '/v0/profile/addresses',
              200,
              headers.merge('_data' => address.as_json)
            )
          end
        end

        it 'supports putting va_profile address data' do
          expect(subject).to validate(:put, '/v0/profile/addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/put_address_success') do
            address = build(:va_profile_v3_address, id: 15_035)

            expect(subject).to validate(
              :put,
              '/v0/profile/addresses',
              200,
              headers.merge('_data' => address.as_json)
            )
          end
        end

        it 'supports deleting va_profile address data' do
          expect(subject).to validate(:delete, '/v0/profile/addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/delete_address_success') do
            address = build(:va_profile_v3_address, id: 15_035)

            expect(subject).to validate(
              :delete,
              '/v0/profile/addresses',
              200,
              headers.merge('_data' => address.as_json)
            )
          end
        end

        it 'supports posting to initialize a vet360_id' do
          expect(subject).to validate(:post, '/v0/profile/initialize_vet360_id', 401)
          VCR.use_cassette('va_profile/v2/person/init_vet360_id_success') do
            expect(subject).to validate(
              :post,
              '/v0/profile/initialize_vet360_id',
              200,
              headers.merge('_data' => {})
            )
          end
        end
      end
    end
  end
end