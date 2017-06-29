# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'in progress forms', type: :request do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:loa3_user) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    allow(FormProfile).to receive(:load_form_mapping).with('FAKEFORM').and_return(
      'veteran_full_name' => %w(identity_information full_name),
      'gender' => %w(identity_information gender),
      'veteran_date_of_birth' => %w(identity_information date_of_birth),
      'veteran_social_security_number' => %w(identity_information ssn),
      'veteran_address' => %w(contact_information address),
      'home_phone' => %w(contact_information home_phone)
    )
  end

  describe '#index' do
    let!(:in_progress_form_edu) { FactoryGirl.create(:in_progress_form, form_id: '22-1990', user_uuid: user.uuid) }
    let!(:in_progress_form_hca) { FactoryGirl.create(:in_progress_form, form_id: '1010ez', user_uuid: user.uuid) }
    subject do
      get v0_in_progress_forms_url, nil, auth_header
    end

    it 'returns details about saved forms' do
      subject
      items = JSON.parse(response.body)['data']
      expect(items.size).to eq(2)
      expect(items.dig(0, 'attributes', 'form_id')).to be_a(String)
    end
  end

  describe '#show' do
    let!(:in_progress_form) { FactoryGirl.create(:in_progress_form, user_uuid: user.uuid) }

    context 'when a form is found' do
      subject do
        get v0_in_progress_form_url(in_progress_form.form_id), nil, auth_header
      end

      it 'returns the form as JSON' do
        subject
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq({
          'form_data' => JSON.parse(in_progress_form.form_data),
          'metadata' => in_progress_form.metadata
        }.to_json)
      end

      context 'with the x key inflection header set' do
        let(:form_data) do
          { foo_bar: 1 }
        end

        before do
          auth_header['HTTP_X_KEY_INFLECTION'] = 'camel'
          in_progress_form.update(form_data: form_data)
        end

        it 'converts the json keys' do
          subject
          expect(response.body).to eq({
            form_data: form_data,
            metadata: in_progress_form.metadata
          }.to_camelback_keys.to_json)
        end
      end
    end

    context 'when a form is not found' do
      it 'returns pre-fill data' do
        get v0_in_progress_form_url('FAKEFORM'), nil, auth_header
        expect(JSON.parse(response.body)['form_data']).to eq(
          'veteranFullName' => {
            'first' => user.first_name&.capitalize,
            'last' => user.last_name&.capitalize,
            'suffix' => user.va_profile.suffix
          },
          'gender' => user.gender,
          'veteranDateOfBirth' => user.birth_date,
          'veteranSocialSecurityNumber' => user.ssn.to_s,
          'veteranAddress' => {
            'street' => user.va_profile.address.street,
            'city' => user.va_profile.address.city,
            'state' => user.va_profile.address.state,
            'country' => user.va_profile.address.country,
            'postal_code' => user.va_profile.address.postal_code
          },
          'homePhone' => user.va_profile.home_phone.gsub(/[^\d]/, '')
        )
      end
    end

    context 'when a form mapping is not found' do
      it 'returns a 500' do
        get v0_in_progress_form_url('foo'), nil, auth_header
        expect(response).to have_http_status(500)
      end
    end
  end

  describe '#update' do
    context 'with a new form' do
      let(:new_form) { FactoryGirl.build(:in_progress_form, user_uuid: user.uuid) }

      it 'inserts the form', run_at: '2017-01-01' do
        expect do
          put v0_in_progress_form_url(new_form.form_id), {
            form_data: new_form.form_data,
            metadata: new_form.metadata
          }.to_json, auth_header.merge('CONTENT_TYPE' => 'application/json')
        end.to change { InProgressForm.count }.by(1)

        expect(response).to have_http_status(:ok)

        in_progress_form = InProgressForm.last
        expect(in_progress_form.form_data).to eq(new_form.form_data)
        expect(in_progress_form.metadata).to eq(
          'version' => 1,
          'return_url' => 'foo.com',
          'expires_at' => 1_488_412_800,
          'last_updated' => 1_483_228_800
        )
      end

      context 'when an error occurs' do
        it 'returns an error response' do
          allow_any_instance_of(InProgressForm).to receive(:update).and_raise(ActiveRecord::ActiveRecordError)
          put v0_in_progress_form_url(new_form.form_id), { form_data: new_form.form_data }, auth_header
          expect(response).to have_http_status(:error)
          expect(Oj.load(response.body)['errors'].first['detail']).to eq('Internal server error')
        end
      end
    end

    context 'with an existing form' do
      let!(:other_existing_form) { create(:in_progress_form, form_id: 'jksdfjk') }
      let(:existing_form) { FactoryGirl.create(:in_progress_form, user_uuid: user.uuid) }
      let(:update_form) { FactoryGirl.create(:in_progress_update_form, user_uuid: user.uuid) }

      it 'updates the right form' do
        put v0_in_progress_form_url(existing_form.form_id), { form_data: update_form.form_data }, auth_header
        expect(response).to have_http_status(:ok)

        expect(existing_form.reload.form_data).to eq(update_form.form_data)
      end
    end
  end

  describe '#destroy' do
    let!(:in_progress_form) { FactoryGirl.create(:in_progress_form, user_uuid: user.uuid) }

    context 'when a form is found' do
      subject do
        delete v0_in_progress_form_url(in_progress_form.form_id), nil, auth_header
      end

      it 'returns the deleted form id' do
        expect { subject }.to change {
          InProgressForm.count
        }.from(1).to(0)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
