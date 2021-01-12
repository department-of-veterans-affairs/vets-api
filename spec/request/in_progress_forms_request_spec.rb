# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::InProgressFormsController, type: :request do
  it_behaves_like 'a controller that does not log 404 to Sentry'

  context 'with a user' do
    let(:loa3_user) { build(:user, :loa3) }
    let(:loa1_user) { build(:user, :loa1) }

    before do
      sign_in_as(user)
      enabled_forms = FormProfile.prefill_enabled_forms << 'FAKEFORM'
      allow(FormProfile).to receive(:prefill_enabled_forms).and_return(enabled_forms)
      allow(FormProfile).to receive(:load_form_mapping).with('FAKEFORM').and_return(
        'veteran_full_name' => %w[identity_information full_name],
        'gender' => %w[identity_information gender],
        'veteran_date_of_birth' => %w[identity_information date_of_birth],
        'veteran_social_security_number' => %w[identity_information ssn],
        'veteran_address' => %w[contact_information address],
        'home_phone' => %w[contact_information home_phone]
      )
    end

    describe '#index' do
      subject do
        get v0_in_progress_forms_url, params: nil
      end

      let(:user) { loa3_user }
      let!(:in_progress_form_edu) do
        FactoryBot.create(:in_progress_form, :with_nested_metadata, form_id: '22-1990', user_uuid: user.uuid)
      end
      let!(:in_progress_form_hca) { FactoryBot.create(:in_progress_form, form_id: '1010ez', user_uuid: user.uuid) }

      context 'when the user is not loa3' do
        let(:user) { loa1_user }
        let(:top_level_keys) { response_body.keys }
        let(:data) { response_body['data'] }
        let(:in_progress_form_with_nested_hash) { data.find { |ipf| ipf['attributes']['metadata']['how_now'] } }
        let(:metadata_returned_with_the_request) { in_progress_form_with_nested_hash['attributes']['metadata'] }
        let(:metadata_before_the_request) { in_progress_form_edu.metadata }

        def response_body
          JSON.parse response.body
        end

        it 'returns a 200' do
          subject
          expect(response).to have_http_status(:ok)
        end

        it 'has the correct shape (JSON:API), with snake_case keys' do
          subject
          expect(response_body).to be_a Hash
          expect(top_level_keys).to contain_exactly 'data'
          expect(data).to be_an Array
          expect(data.count).to be > 1
          data.each do |ipf|
            expect(ipf.keys).to contain_exactly('id', 'type', 'attributes')
            expect(ipf['type']).to eq 'in_progress_forms'
            expect(ipf['attributes'].keys).to contain_exactly('form_id', 'created_at', 'updated_at', 'metadata')
          end
        end

        it 'snake_cased keys *inside* attributes' do
          subject
          expect(metadata_returned_with_the_request['how_now']['brown_cow']).to be_present
        end

        it 'corrupts complicated keys' do
          subject
          expect(metadata_before_the_request['howNow']['brown-cow']['-an eas-i-ly corRupted KEY.'])
            .to be_present
          expect(metadata_returned_with_the_request['how_now']['brown_cow']['-an eas-i-ly corRupted KEY.'])
            .not_to be_present
        end

        context 'with OliveBranch' do
          subject do
            get(
              v0_in_progress_forms_url,
              headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
            )
          end

          let(:in_progress_form_with_nested_hash) { data.find { |ipf| ipf['attributes']['metadata']['howNow'] } }

          it 'has camelCase keys' do
            subject
            expect(response_body).to be_a Hash
            expect(top_level_keys).to contain_exactly 'data'
            expect(data).to be_an Array
            expect(data.count).to be > 1
            data.each do |ipf|
              expect(ipf.keys).to contain_exactly('id', 'type', 'attributes')
              expect(ipf['type']).to eq 'in_progress_forms'
              expect(ipf['attributes'].keys).to contain_exactly('formId', 'createdAt', 'updatedAt', 'metadata')
            end
          end

          it 'camelCased keys *inside* attributes' do
            subject
            expect(metadata_returned_with_the_request['howNow']['brownCow']).to be_present
          end

          it 'corrupts complicated keys' do
            subject
            expect(metadata_before_the_request['howNow']['brown-cow']['-an eas-i-ly corRupted KEY.'])
              .to be_present
            expect(metadata_returned_with_the_request['howNow']['brownCow']['-an eas-i-ly corRupted KEY.'])
              .not_to be_present
            puts metadata_returned_with_the_request['howNow']['brownCow'].keys
          end
        end
      end

      context 'when the user is not a test account' do
        let(:user) { build(:user, :loa3, ssn: '000010002') }

        it 'returns a 200' do
          subject
          expect(response).to have_http_status(:ok)
        end
      end

      it 'returns details about saved forms' do
        subject
        items = JSON.parse(response.body)['data']
        expect(items.size).to eq(2)
        expect(items.dig(0, 'attributes', 'form_id')).to be_a(String)
      end
    end

    describe '#show' do
      let(:user) { loa3_user }
      let!(:in_progress_form) { FactoryBot.create(:in_progress_form, user_uuid: user.uuid) }

      context 'when the user is not loa3' do
        let(:user) { loa1_user }

        it 'returns a 200' do
          get v0_in_progress_form_url(in_progress_form.form_id), params: nil
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when a form is found' do
        it 'returns the form as JSON' do
          get v0_in_progress_form_url(in_progress_form.form_id), params: nil

          expect(response).to have_http_status(:ok)
          expect(response.body).to eq({
            'form_data' => JSON.parse(in_progress_form.form_data),
            'metadata' => in_progress_form.metadata
          }.to_json)
        end

        context 'with the x key inflection header set' do
          it 'converts the json keys' do
            form_data = { 'view:hasVaMedicalRecords' => true }

            in_progress_form.update(form_data: form_data)
            get v0_in_progress_form_url(in_progress_form.form_id),
                params: nil,
                headers: { 'HTTP_X_KEY_INFLECTION' => 'camel' }
            body = JSON.parse(response.body)
            expect(body.keys).to include('formData', 'metadata')
            expect(body['formData'].keys).to include('view:hasVaMedicalRecords')
            expect(body['formData']['view:hasVaMedicalRecords']).to eq form_data['view:hasVaMedicalRecords']
            expect(body['metadata'])
              .to eq in_progress_form.metadata.transform_keys { |key| key.underscore.camelize(:lower) }
          end
        end
      end

      context 'when a form is not found' do
        let(:street_check) { build(:street_check) }

        it 'returns pre-fill data' do
          _, phone_response = stub_evss_pciu(user)

          get v0_in_progress_form_url('FAKEFORM'), params: nil

          expected_data = {
            'veteranFullName' => {
              'first' => user.first_name&.capitalize,
              'last' => user.last_name&.capitalize
            },
            'gender' => user.gender,
            'veteranDateOfBirth' => user.birth_date,
            'veteranSocialSecurityNumber' => user.ssn.to_s,
            'veteranAddress' => {
              'street' => street_check[:street],
              'street2' => street_check[:street2],
              'city' => user.va_profile.address.city,
              'state' => user.va_profile.address.state,
              'country' => user.va_profile.address.country,
              'postalCode' => user.va_profile.address.postal_code[0..4]
            },
            'homePhone' => "#{phone_response.country_code}#{phone_response.number}#{phone_response.extension}"
          }

          if user.va_profile&.normalized_suffix.present?
            expected_data['veteranFullName']['suffix'] = user.va_profile&.normalized_suffix
          end

          expect(JSON.parse(response.body)['form_data']).to eq(expected_data)
        end
      end

      context 'when a form mapping is not found' do
        it 'returns a 500' do
          get v0_in_progress_form_url('foo'), params: nil
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end

    describe '#update' do
      let(:user) { loa3_user }

      context 'with a new form' do
        let(:new_form) { FactoryBot.build(:in_progress_form, user_uuid: user.uuid) }

        context 'when the user is not loa3' do
          let(:user) { loa1_user }

          it 'returns a 200' do
            put v0_in_progress_form_url(new_form.form_id), params: {
              form_data: new_form.form_data,
              metadata: new_form.metadata
            }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
            expect(response).to have_http_status(:ok)
          end
        end

        it 'inserts the form', run_at: '2017-01-01' do
          expect do
            put v0_in_progress_form_url(new_form.form_id), params: {
              form_data: new_form.form_data,
              metadata: new_form.metadata
            }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
          end.to change(InProgressForm, :count).by(1)

          expect(response).to have_http_status(:ok)

          in_progress_form = InProgressForm.last
          expect(in_progress_form.form_data).to eq(new_form.form_data)
          expect(in_progress_form.metadata).to eq(
            'version' => 1,
            'return_url' => 'foo.com',
            'expires_at' => 1_488_412_800,
            'last_updated' => 1_483_228_800,
            'in_progress_form_id' => in_progress_form.id
          )
        end

        context 'when an error occurs' do
          it 'returns an error response' do
            allow_any_instance_of(InProgressForm).to receive(:update!).and_raise(ActiveRecord::ActiveRecordError)
            put v0_in_progress_form_url(new_form.form_id), params: { form_data: new_form.form_data }
            expect(response).to have_http_status(:internal_server_error)
            expect(Oj.load(response.body)['errors'].first['detail']).to eq('Internal server error')
          end
        end
      end

      context 'with an existing form' do
        let!(:other_existing_form) { create(:in_progress_form, form_id: 'jksdfjk') }
        let(:existing_form) { create(:in_progress_form, user_uuid: user.uuid) }
        let(:update_form) { build(:in_progress_update_form, user_uuid: user.uuid) }

        it 'updates the right form' do
          put v0_in_progress_form_url(existing_form.form_id), params: { form_data: update_form.form_data }
          expect(response).to have_http_status(:ok)

          expect(existing_form.reload.form_data).to eq(update_form.form_data)
        end
      end
    end

    describe '#destroy' do
      let(:user) { loa3_user }
      let!(:in_progress_form) { FactoryBot.create(:in_progress_form, user_uuid: user.uuid) }

      context 'when the user is not loa3' do
        let(:user) { loa1_user }

        it 'returns a 200' do
          delete v0_in_progress_form_url(in_progress_form.form_id), params: nil
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when a form is not found' do
        subject do
          delete v0_in_progress_form_url('ksdjfkjdf'), params: nil
        end

        it 'returns a 404' do
          subject
          expect(response.code).to eq('404')
        end
      end

      context 'when a form is found' do
        subject do
          delete v0_in_progress_form_url(in_progress_form.form_id), params: nil
        end

        it 'returns the deleted form id' do
          expect { subject }.to change(InProgressForm, :count).by(-1)
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  context 'without a user' do
    describe '#show' do
      let(:in_progress_form) { FactoryBot.create(:in_progress_form) }

      it 'returns a 401' do
        get v0_in_progress_form_url(in_progress_form.form_id), params: nil

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
