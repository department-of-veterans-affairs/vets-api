# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

# Because of the shared_example this is behaving like a controller and request spec
RSpec.describe V0::InProgressFormsController do
  it_behaves_like 'a controller that does not log 404 to Sentry'

  context 'with a user' do
    let(:loa3_user) { build(:user, :loa3, :with_terms_of_use_agreement) }
    let(:loa1_user) { build(:user, :loa1, :with_terms_of_use_agreement, icn: nil) }

    before do
      sign_in_as(user)
      enabled_forms = FormProfile.prefill_enabled_forms << 'FAKEFORM'
      allow(FormProfile).to receive(:prefill_enabled_forms).and_return(enabled_forms)
      allow(FormProfile).to receive(:load_form_mapping).and_call_original
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
      subject { get v0_in_progress_forms_url, params: nil }

      let(:user) { loa3_user }
      let!(:in_progress_form_edu) do
        create(:in_progress_form, :with_nested_metadata, form_id: '22-1990', user_uuid: user.uuid)
      end
      let!(:in_progress_form_hca) { create(:in_progress_form, form_id: '1010ez', user_uuid: user.uuid) }

      context 'when the user is not loa3' do
        let(:user) { loa1_user }
        let(:response_body) { JSON.parse(response.body) }
        let(:top_level_keys) { response_body.keys }
        let(:data) { response_body['data'] }
        let(:in_progress_form_with_nested_hash) { data.find { |ipf| ipf['attributes']['metadata']['howNow'] } }
        let(:metadata_returned_with_the_request) { in_progress_form_with_nested_hash['attributes']['metadata'] }
        let(:metadata_before_the_request) { in_progress_form_edu.metadata }

        it 'returns a 200' do
          subject
          expect(response).to have_http_status(:ok)
        end

        it 'has the correct shape (JSON:API), and has camelCase keys all the way down to attributes' do
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

        it 'does NOT transform keys inside attributes' do
          subject
          expect(metadata_returned_with_the_request['howNow']['brown-cow']).to be_present
        end

        it 'does NOT corrupt complicated keys' do
          subject
          expect(metadata_before_the_request['howNow']['brown-cow']['-an eas-i-ly corRupted KEY.'])
            .to be_present
          expect(metadata_returned_with_the_request['howNow']['brown-cow']['-an eas-i-ly corRupted KEY.'])
            .to be_present
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
            expect(metadata_returned_with_the_request['howNow']['brownCow']).to be_present
            expect(metadata_returned_with_the_request['howNow']['brownCow']['-an eas-i-ly corRupted KEY.'])
              .not_to be_present
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
        expect(items.dig(0, 'attributes', 'formId')).to be_a(String)
      end
    end

    describe '#show' do
      let(:user) { build(:user, :loa3, address: build(:mpi_profile_address)) }
      let!(:in_progress_form) { create(:in_progress_form, :with_nested_metadata, user_uuid: user.uuid) }

      context 'when the user is not loa3' do
        let(:user) { loa1_user }

        it 'returns a 403' do
          get v0_in_progress_form_url(in_progress_form.form_id), params: nil
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when a form is found' do
        it 'returns the form as JSON' do
          get v0_in_progress_form_url(in_progress_form.form_id), params: nil

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(
            'formData' => JSON.parse(in_progress_form.form_data),
            'metadata' => in_progress_form.metadata
          )
        end

        context 'with the x key inflection header set' do
          it 'converts the json keys' do
            form_data = { 'view:hasVaMedicalRecords' => true }

            in_progress_form.update(form_data:)
            get v0_in_progress_form_url(in_progress_form.form_id),
                headers: { 'HTTP_X_KEY_INFLECTION' => 'camel' }
            body = JSON.parse(response.body)
            expect(body.keys).to include('formData', 'metadata')
            expect(body['formData'].keys).to include('view:hasVaMedicalRecords')
            expect(body['formData']['view:hasVaMedicalRecords']).to eq form_data['view:hasVaMedicalRecords']
            expect(body['formData'].keys).not_to include('Hello, there Sam-I -Am!')
            expect(body['metadata']['howNow']['brownCow']).to be_present
            expect(body['metadata']['howNow']['brownCow']['-an eas-i-ly corRupted KEY.']).not_to be_present
          end
        end

        context 'without the inflection header' do
          it 'has camelCase top-level keys, but does not transform nested keys' do
            form_data = {
              'view:hasVaMedicalRecords' => true,
              'Hello, there Sam-I -Am!' => true
            }

            in_progress_form.update(form_data:)
            get v0_in_progress_form_url(in_progress_form.form_id)
            body = JSON.parse(response.body)
            expect(body.keys).to include('formData', 'metadata')
            expect(body['formData'].keys).to include('view:hasVaMedicalRecords')
            expect(body['formData']['view:hasVaMedicalRecords']).to eq form_data['view:hasVaMedicalRecords']
            expect(body['formData'].keys).to include('Hello, there Sam-I -Am!')
            expect(body['formData']['Hello, there Sam-I -Am!']).to eq form_data['Hello, there Sam-I -Am!']
            expect(body['metadata']['howNow']['brown-cow']['-an eas-i-ly corRupted KEY.']).to be_present
            expect(body['metadata']).to eq in_progress_form.metadata
          end
        end
      end

      context 'for an MDOT form sans addresses' do
        let(:user_details) do
          {
            first_name: 'Greg',
            last_name: 'Anderson',
            middle_name: 'A',
            birth_date: '19910405',
            ssn: '000550237'
          }
        end

        let(:user) { build(:user, :loa3, user_details) }

        it 'returns the form as JSON' do
          VCR.insert_cassette(
            'mdot/get_supplies_null_addresses_200',
            match_requests_on: %i[method uri headers],
            erb: { icn: user.icn }
          )
          get v0_in_progress_form_url('MDOT'), params: nil
          expect(response).to have_http_status(:ok)
          VCR.eject_cassette
        end
      end

      context 'when a form is not found' do
        let(:street_check) { build(:street_check) }
        let(:expected_data) do
          {
            'veteranFullName' => {
              'first' => user.first_name&.capitalize,
              'last' => user.last_name&.capitalize
            },
            'gender' => user.gender,
            'veteranDateOfBirth' => user.birth_date,
            'veteranSocialSecurityNumber' => user.ssn.to_s,
            'veteranAddress' => {
              'street' => '140 Rock Creek Rd',
              'city' => 'Washington',
              'state' => 'DC',
              'country' => 'USA',
              'postalCode' => '20011'
            },
            'homePhone' => '3035551234'
          }
        end

        it 'returns pre-fill data' do
          expected_data
          get v0_in_progress_form_url('FAKEFORM'), params: nil

          expected_data['veteranFullName']['suffix'] = user.normalized_suffix if user.normalized_suffix.present?

          check_case_of_keys_recursively = lambda do |value|
            case value
            when Hash
              value.each_key do |key|
                expect(key).not_to include '_' # ensure all keys are camelCase
                check_case_of_keys_recursively.call(value[key])
              end
            when Array
              value.each { |v| check_case_of_keys_recursively.call(v) }
            end
          end
          check_case_of_keys_recursively.call(JSON.parse(response.body))

          expect(JSON.parse(response.body)['formData']).to eq(expected_data)
        end

        it 'returns pre-fill data the same way, with or without the Inflection heaader' do
          expected_data

          get v0_in_progress_form_url('FAKEFORM')
          without_inflection_header = JSON.parse(response.body)

          get v0_in_progress_form_url('FAKEFORM'),
              headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
          with_inflection_header = JSON.parse(response.body)

          expect(without_inflection_header).to eq with_inflection_header
        end
      end

      context 'when a form mapping is not found' do
        it 'returns a 500' do
          allow(FormProfile).to receive(:prefill_enabled_forms).and_return(['FOO'])

          get v0_in_progress_form_url('foo'), params: nil
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end

    describe '#update' do
      let(:user) { loa3_user }

      before do
        allow(Flipper).to receive(:enabled?).with(:intent_to_file_lighthouse_enabled,
                                                  instance_of(User)).and_return(true)
      end

      context 'with a new form' do
        let(:new_form) { create(:in_progress_form, user_uuid: user.uuid, user_account: user.user_account) }

        context 'when handling race condition' do
          context 'with in_progress_form_atomicity flipper on' do
            before do
              allow(Flipper).to receive(:enabled?).with(:in_progress_form_atomicity,
                                                        instance_of(User)).and_return(true)
            end

            it 'handles concurrent requests creating the same form' do
              form_id = '22-1990'
              form_data = { test: 'data' }.to_json
              metadata = { version: 1 }

              # Simulate race condition: two concurrent requests both find no existing form
              # then both try to create one
              allow(InProgressForm).to receive(:form_for_user).and_return(nil).twice

              # First request should succeed with create_or_find_by!
              expect do
                put v0_in_progress_form_url(form_id), params: {
                  form_data:,
                  metadata:
                }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
              end.to change(InProgressForm, :count).by(1)

              expect(response).to have_http_status(:ok)

              # Second concurrent request should not raise duplicate key error
              # It should find the existing form or handle the constraint violation
              expect do
                put v0_in_progress_form_url(form_id), params: {
                  form_data: { test: 'updated_data' }.to_json,
                  metadata:
                }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
              end.not_to change(InProgressForm, :count)

              expect(response).to have_http_status(:ok)

              # Verify the form was updated with the second request's data
              updated_form = InProgressForm.find_by(form_id:, user_uuid: user.uuid)
              expect(JSON.parse(updated_form.form_data)).to eq({ 'test' => 'updated_data' })
            end
          end

          context 'with in_progress_form_atomicity flipper off' do
            before do
              allow(Flipper).to receive(:enabled?).with(:in_progress_form_atomicity,
                                                        instance_of(User)).and_return(false)
            end

            it 'fails when concurrent requests create the same form' do
              form_id = '22-1990'
              form_data = { test: 'data' }.to_json
              metadata = { version: 1 }

              # Simulate race condition: two concurrent requests both find no existing form
              # then both try to create one
              allow(InProgressForm).to receive(:form_for_user).and_return(nil).twice

              # First request should succeed
              expect do
                put v0_in_progress_form_url(form_id), params: {
                  form_data:,
                  metadata:
                }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
              end.to change(InProgressForm, :count).by(1)

              expect(response).to have_http_status(:ok)

              # Second concurrent request will raise duplicate key error
              # since the non-atomic path does not handle it
              expect do
                put v0_in_progress_form_url(form_id), params: {
                  form_data: { test: 'updated_data' }.to_json,
                  metadata:
                }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
              end.not_to change(InProgressForm, :count)

              expect(response).to have_http_status(:internal_server_error)

              # Verify the form was not updated with the second request's data
              updated_form = InProgressForm.find_by(form_id:, user_uuid: user.uuid)
              expect(JSON.parse(updated_form.form_data)).to eq({ 'test' => 'data' })
            end
          end
        end

        context 'when the user is not loa3' do
          let(:user) { loa1_user }

          it 'returns a 200 with camelCases JSON' do
            put v0_in_progress_form_url(new_form.form_id), params: {
              form_data: new_form.form_data,
              metadata: new_form.metadata
            }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
            expect(response).to have_http_status(:forbidden)
          end
        end

        it 'runs the LogEmailDiffJob job' do
          new_form.form_id = '1010ez'
          allow(HCA::LogEmailDiffJob).to receive(:perform_async)
          new_form.save!
          expect(HCA::LogEmailDiffJob).to receive(:perform_async).with(new_form.id, user.uuid,
                                                                       user.user_account_uuid)

          put v0_in_progress_form_url(new_form.form_id), params: {
            formData: new_form.form_data,
            metadata: new_form.metadata
          }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
        end

        it 'inserts the form', run_at: '2017-01-01' do
          expect do
            put v0_in_progress_form_url(new_form.form_id), params: {
              formData: new_form.form_data,
              metadata: new_form.metadata
            }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
          end.to change(InProgressForm, :count).by(1)

          expect(response).to have_http_status(:ok)

          in_progress_form = InProgressForm.last
          expect(in_progress_form.form_data).to eq(new_form.form_data)
          expect(in_progress_form.metadata).to eq(
            'version' => 1,
            'return_url' => 'foo.com', # <- the factory uses snake_case (as most forms are still using OliveBranch)
            'createdAt' => 1_483_228_800,
            'expiresAt' => 1_488_412_800, # <- these are inserted by the model on access, and will always be camelCase
            'lastUpdated' => 1_483_228_800, # now so that the front end will always receive camelCase (with or without
            'inProgressFormId' => in_progress_form.id, # the inflection header)
            'submission' => { 'status' => false, 'error_message' => false, 'id' => false, 'timestamp' => false,
                              'has_attempted_submit' => false }
          )
        end

        it 'sets expires_at to 60 days from now for regular forms', run_at: '2017-01-01' do
          put v0_in_progress_form_url(new_form.form_id), params: {
            formData: new_form.form_data,
            metadata: new_form.metadata
          }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }

          expect(response).to have_http_status(:ok)

          in_progress_form = InProgressForm.last
          expect(in_progress_form.expires_at.to_i).to eq(1_488_412_800)
        end

        it 'preserves existing expires_at for form526 (skippable form)', run_at: '2017-01-01' do
          form526 = create(:in_progress_526_form, user_uuid: user.uuid, user_account: user.user_account)
          # Factory sets expires_at to 1 year from now
          initial_expires_at = form526.expires_at

          put v0_in_progress_form_url(form526.form_id), params: {
            formData: form526.form_data,
            metadata: form526.metadata
          }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }

          expect(response).to have_http_status(:ok)

          in_progress_form = InProgressForm.find_by(form_id: form526.form_id, user_uuid: user.uuid)
          # expires_at should be preserved, not updated to current time
          expect(in_progress_form.expires_at).to eq(initial_expires_at)
        end

        it 'can have nil metadata' do
          put v0_in_progress_form_url(new_form.form_id),
              params: { form_data: { greeting: 'Hello!' } }.to_json,
              headers: { 'CONTENT_TYPE' => 'application/json' }
          expect(response).to have_http_status(:ok)
        end

        it "can't have nil formData" do
          put v0_in_progress_form_url(new_form.form_id)
          expect(response).to have_http_status(:error)
        end

        it "can't have non-hash formData" do
          put v0_in_progress_form_url(new_form.form_id),
              params: { form_data: '' }.to_json,
              headers: { 'CONTENT_TYPE' => 'application/json' }
          expect(response).to have_http_status(:error)
        end

        it "can't have an empty hash for formData" do
          put v0_in_progress_form_url(new_form.form_id),
              params: {}.to_json,
              headers: { 'CONTENT_TYPE' => 'application/json' }
          expect(response).to have_http_status(:error)
        end

        context 'when an error occurs' do
          it 'returns an error response' do
            allow_any_instance_of(InProgressForm).to receive(:update!).and_raise(ActiveRecord::ActiveRecordError)
            put v0_in_progress_form_url(new_form.form_id), params: { form_data: new_form.form_data }
            expect(response).to have_http_status(:internal_server_error)
            expect(Oj.load(response.body)['errors'].first['detail']).to eq('Internal server error')
          end
        end

        context 'when form type is pension' do
          it 'creates pension form successfully' do
            put v0_in_progress_form_url('21P-527EZ'),
                params: {
                  formData: new_form.form_data,
                  metadata: new_form.metadata
                }.to_json,
                headers: { 'CONTENT_TYPE' => 'application/json' }

            expect(response).to have_http_status(:ok)
            latest_form = InProgressForm.last
            expect(latest_form.form_id).to eq('21P-527EZ')
          end
        end
      end

      context 'with an existing form' do
        let!(:other_existing_form) { create(:in_progress_form, form_id: 'jksdfjk') }
        let(:existing_form) { create(:in_progress_form, user_uuid: user.uuid, user_account: user.user_account) }
        let(:form_data) { { some_form_data: 'form-data' }.to_json }

        it 'updates the right form' do
          put v0_in_progress_form_url(existing_form.form_id), params: { form_data: }

          expect(response).to have_http_status(:ok)

          expect(existing_form.reload.form_data).to eq(form_data)
        end

        it 'updates expires_at on each update', run_at: '2017-01-01' do
          # Set initial expires_at to a different time
          existing_form.update!(expires_at: Time.zone.parse('2017-02-01'))
          initial_expires_at = existing_form.expires_at

          put v0_in_progress_form_url(existing_form.form_id), params: { form_data: }

          expect(response).to have_http_status(:ok)

          existing_form.reload
          # expires_at should be updated to 60 days from 2017-01-01 = 1488412800
          expect(existing_form.expires_at.to_i).to eq(1_488_412_800)
          expect(existing_form.expires_at).not_to eq(initial_expires_at)
        end

        it 'preserves expires_at for form526 on update', run_at: '2017-01-01' do
          form526 = create(:in_progress_526_form, user_uuid: user.uuid, user_account: user.user_account)
          # Set a specific expires_at
          form526.update!(expires_at: Time.zone.parse('2018-06-01'))
          initial_expires_at = form526.expires_at
          form_data = { updated: 'data' }.to_json

          put v0_in_progress_form_url(form526.form_id), params: { form_data: }

          expect(response).to have_http_status(:ok)

          form526.reload
          # expires_at should remain unchanged for form526 (skippable form)
          expect(form526.expires_at).to eq(initial_expires_at)
        end

        context 'has checked \'One or more of my rated conditions that have gotten worse\'' do
          let!(:existing_form) { create(:in_progress_526_form, user_uuid: user.uuid) }
          let(:form_data) do
            { 'view:claim_type': {
                'view:claiming_increase': true
              },
              rated_disabilities: [
                { name: 'Hypertension',
                  diagnostic_code: ClaimFastTracking::DiagnosticCodes::HYPERTENSION }
              ] }.to_json
          end

          before { allow(StatsD).to receive(:increment) }

          context 'has no ratings with maximum_rating_percentage' do
            it 'updates form with cfiMetric metadata but does not call StatsD' do
              put v0_in_progress_form_url(existing_form.form_id),
                  params: { form_data:, metadata: existing_form.metadata }
              expect(response).to have_http_status(:ok)
              expect(existing_form.reload.metadata.keys).to include('cfiMetric')
              expect(StatsD).to have_received(:increment).with('api.max_cfi.on_rated_disabilities',
                                                               tags: ['has_max_rated:false']).once
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.rated_disabilities', anything)
            end
          end

          context 'has rated disability with maximum_rating_percentage' do
            let(:form_data) do
              { 'view:claim_type': {
                  'view:claiming_increase': true
                },
                rated_disabilities: [
                  { name: 'Tinnitus',
                    diagnostic_code: ClaimFastTracking::DiagnosticCodes::TINNITUS,
                    rating_percentage: 10,
                    maximum_rating_percentage: 10 },
                  { name: 'Hypertension',
                    diagnostic_code: ClaimFastTracking::DiagnosticCodes::HYPERTENSION,
                    rating_percentage: 20 }
                ] }.to_json
            end

            it 'updates form and includes cfiMetric in metadata, and logs metric' do
              put v0_in_progress_form_url(existing_form.form_id),
                  params: { form_data:, metadata: existing_form.metadata }
              expect(response).to have_http_status(:ok)
              expect(existing_form.reload.metadata.keys).to include('cfiMetric')
              expect(StatsD).to have_received(:increment).with('api.max_cfi.on_rated_disabilities',
                                                               tags: ['has_max_rated:true']).once
              expect(StatsD).to have_received(:increment).with('api.max_cfi.rated_disabilities',
                                                               tags: ['diagnostic_code:6260']).once
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.rated_disabilities',
                                                                   tags: ['diagnostic_code:7101'])
            end

            context 'if updated twice' do
              it 'only logs metric once' do
                put v0_in_progress_form_url(existing_form.form_id),
                    params: { form_data:, metadata: existing_form.metadata }
                expect(response).to have_http_status(:ok)
                expect(existing_form.reload.metadata.keys).to include('cfiMetric')

                put v0_in_progress_form_url(existing_form.form_id),
                    params: { form_data:, metadata: existing_form.metadata }
                expect(response).to have_http_status(:ok)
                expect(existing_form.reload.metadata.keys).to include('cfiMetric')
                expect(StatsD).to have_received(:increment).with('api.max_cfi.on_rated_disabilities',
                                                                 tags: ['has_max_rated:true']).once
                expect(StatsD).to have_received(:increment).with('api.max_cfi.rated_disabilities',
                                                                 tags: ['diagnostic_code:6260']).once
                expect(StatsD).not_to have_received(:increment).with('api.max_cfi.rated_disabilities',
                                                                     tags: ['diagnostic_code:7101'])
              end
            end
          end
        end

        context 'has not checked \'One or more of my rated conditions that have gotten worse\'' do
          before { allow(StatsD).to receive(:increment) }

          let(:existing_form) { create(:in_progress_526_form, user_uuid: user.uuid) }

          it 'updates form with cfiMetric metadata but does not call StatsD' do
            put v0_in_progress_form_url(existing_form.form_id),
                params: { form_data:, metadata: existing_form.metadata }
            expect(response).to have_http_status(:ok)
            expect(existing_form.reload.metadata.keys).to include('cfiMetric')
            expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on_rated_disabilities', anything)
          end
        end
      end
    end

    describe '#destroy' do
      let(:user) { loa3_user }
      let!(:in_progress_form) { create(:in_progress_form, user_uuid: user.uuid) }

      context 'when the user is not loa3' do
        let(:user) { loa1_user }

        it 'returns a 200 with camelCase JSON' do
          delete v0_in_progress_form_url(in_progress_form.form_id), params: nil
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes'].keys)
            .to contain_exactly('formId', 'createdAt', 'updatedAt', 'metadata')
        end
      end

      context 'when a form is not found' do
        subject do
          delete v0_in_progress_form_url('ksdjfkjdf'), params: nil
        end

        it 'returns a 404' do
          subject
          expect(response).to have_http_status(:not_found)
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
      let(:in_progress_form) { create(:in_progress_form) }

      it 'returns a 401' do
        get v0_in_progress_form_url(in_progress_form.form_id), params: nil

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
