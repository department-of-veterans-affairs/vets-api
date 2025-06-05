# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe 'AccreditedRepresentativePortal::V0::User', type: :request do
  describe '#show' do
    context 'when not authenticated' do
      it 'responds with unauthorized' do
        get '/accredited_representative_portal/v0/user'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      before { login_as(user) }

      context 'as a user with an in progress form' do
        let(:first_name_value) { Faker::Name.first_name }
        let(:last_name_value) { Faker::Name.last_name }
        let(:sign_in_service_name_value) { Faker::Company.name }
        let(:in_progress_form_id_value) { Faker::Form.id }
        let!(:expected_created_at) { Time.current }
        let!(:expected_expires_at) { 60.days.from_now }
        let!(:expected_last_updated) { Time.current }

        let(:user) do
          create(
            :representative_user,
            :with_in_progress_form,
            {
              first_name: first_name_value,
              last_name: last_name_value,
              sign_in_service_name: sign_in_service_name_value,
              in_progress_form_id: in_progress_form_id_value
            }
          )
        end

        let!(:in_progress_form_record) do
          InProgressForm.find_by(
            form_id: in_progress_form_id_value,
            user_account_id: user.user_account.id
          )
        end

        around do |example|
          travel_to Time.zone.parse('2024-09-06T16:19:34-04:00') do
            example.run
          end
        end

        it 'responds with the user and their in progress form with explicit keys' do
          get '/accredited_representative_portal/v0/user'

          expect(response).to have_http_status(:ok)

          expect(parsed_response.keys).to match_array(%w[account profile prefillsAvailable inProgressForms])

          # Check 'account' block
          expect(parsed_response['account']).to be_a(Hash)
          expect(parsed_response['account'].keys).to match_array(%w[accountUuid])
          expect(parsed_response['account']['accountUuid']).to eq(user.user_account.id)

          # Check 'profile' block
          expect(parsed_response['profile']).to be_a(Hash)
          expect(parsed_response['profile'].keys).to match_array(%w[firstName lastName verified signIn loa])
          expect(parsed_response['profile']['firstName']).to eq(first_name_value)
          expect(parsed_response['profile']['lastName']).to eq(last_name_value)
          expect(parsed_response['profile']['verified']).to be(true)

          # Check 'profile.signIn' block
          expect(parsed_response['profile']['signIn']).to be_a(Hash)
          expect(parsed_response['profile']['signIn'].keys).to match_array(%w[serviceName])
          expect(parsed_response['profile']['signIn']['serviceName']).to eq(sign_in_service_name_value)

          expect(parsed_response['profile']['loa']).to be_a(Hash)
          expect(parsed_response['profile']['loa']).to eq(user.loa.to_h.stringify_keys)
          expect(parsed_response['profile']['loa'].keys).to include('current')
          expect(parsed_response['profile']['loa'].keys).to include('highest')
          expect(parsed_response['profile']['loa']['current']).to eq(user.loa[:current])
          expect(parsed_response['profile']['loa']['highest']).to eq(user.loa[:highest])

          # Check 'prefillsAvailable' block
          expect(parsed_response['prefillsAvailable']).to be_an(Array)
          expect(parsed_response['prefillsAvailable']).to eq([])

          # Check 'inProgressForms' block
          expect(parsed_response['inProgressForms']).to be_an(Array)
          expect(parsed_response['inProgressForms'].size).to eq(1)

          in_progress_form_response = parsed_response['inProgressForms'].first
          expect(in_progress_form_response).to be_a(Hash)
          expect(in_progress_form_response.keys).to match_array(%w[form metadata lastUpdated])
          expect(in_progress_form_response['form']).to eq(in_progress_form_id_value)

          # Check 'inProgressForms.metadata' block
          metadata_response = in_progress_form_response['metadata']
          expect(metadata_response).to be_a(Hash)
          expect(metadata_response.keys).to match_array(%w[version returnUrl createdAt expiresAt lastUpdated
                                                           inProgressFormId])
          expect(metadata_response['version']).to eq(1)
          expect(metadata_response['returnUrl']).to eq('foo.com')

          expect(metadata_response['createdAt']).to eq(expected_created_at.to_i)
          expect(metadata_response['expiresAt']).to eq(expected_expires_at.to_i)
          expect(metadata_response['lastUpdated']).to eq(expected_last_updated.to_i)

          expect(in_progress_form_record).not_to be_nil, 'InProgressForm record not found ' \
                                                         "with form_id: #{in_progress_form_id_value} " \
                                                         "and user_account_id: #{user.user_account.id}"
          expect(metadata_response['inProgressFormId']).to eq(in_progress_form_record.id)

          expect(in_progress_form_response['lastUpdated']).to eq(expected_last_updated.to_i)
        end
      end
    end
  end
end
