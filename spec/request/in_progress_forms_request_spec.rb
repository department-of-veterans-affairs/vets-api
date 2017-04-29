# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'in progress forms', type: :request do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:loa3_user) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    allow(YAML).to receive(:load_file).and_return(
      'veteran_full_name' => %w(identity_information full_name),
      'gender' => %w(identity_information gender),
      'veteran_date_of_birth' => %w(identity_information date_of_birth),
      'veteran_address' => %w(contact_information address),
      'home_phone' => %w(contact_information home_phone)
    )
  end

  describe 'GET' do
    let!(:in_progress_form) { FactoryGirl.create(:in_progress_form, user_uuid: user.uuid) }

    context 'when a form is found' do
      it 'returns the form as JSON' do
        get v0_in_progress_form_url(in_progress_form.form_id), nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(in_progress_form.form_data)
      end
    end

    context 'when a form is not found' do
      it 'returns pre-fill data' do
        get v0_in_progress_form_url('healthcare_application'), nil, auth_header
        expect(response.body).to eq({
          'veteranFullName' => {
            'first' => user.first_name&.capitalize,
            'middle' => user.middle_name&.capitalize,
            'last' => user.last_name&.capitalize,
            'suffix' => user.va_profile.suffix
          },
          'gender' => user.gender,
          'veteranDateOfBirth' => user.birth_date,
          'veteranAddress' => {
            'street' => user.va_profile.address.street,
            'street_2' => nil,
            'city' => user.va_profile.address.city,
            'state' => user.va_profile.address.state,
            'country' => user.va_profile.address.country,
            'postal_code' => user.va_profile.address.postal_code
          },
          'homePhone' => user.va_profile.home_phone
        }.to_json)
      end
    end

    context 'when a form mapping is not found' do
      it 'returns a 500' do
        get v0_in_progress_form_url('foo'), nil, auth_header
        expect(response).to have_http_status(500)
      end
    end
  end

  describe 'PUT' do
    context 'with a new form' do
      let(:new_form) { FactoryGirl.build(:in_progress_form, user_uuid: user.uuid) }

      it 'inserts the form' do
        expect_any_instance_of(InProgressForm).to receive(:update).with(form_data: new_form.form_data).and_return(true)
        put v0_in_progress_form_url(new_form.form_id), { form_data: new_form.form_data }, auth_header
        expect(response).to have_http_status(:ok)
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
      let(:existing_form) { FactoryGirl.create(:in_progress_form, user_uuid: user.uuid) }
      let(:update_form) { FactoryGirl.create(:in_progress_update_form, user_uuid: user.uuid) }

      it 'updates the form' do
        expect_any_instance_of(InProgressForm).to receive(:update)
          .with(form_data: update_form.form_data).and_return(true)
        put v0_in_progress_form_url(existing_form.form_id), { form_data: update_form.form_data }, auth_header
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
