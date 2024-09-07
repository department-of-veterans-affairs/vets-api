# frozen_string_literal: true

require_relative '../../../rails_helper'
require_relative '../../../support/authentication'

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
        first_name = Faker::Name.first_name
        last_name = Faker::Name.last_name
        sign_in_service_name = Faker::Company.name
        in_progress_form_id = Faker::Form.id
        in_progress_form_return_url = Faker::Internet.url

        let(:user) do
          create(
            :representative_user,
            :with_in_progress_form,
            {
              first_name:, last_name:, sign_in_service_name:,
              in_progress_form_id:, in_progress_form_return_url:
            }
          )
        end

        it 'responds with the user and their in progress form', run_at: '2024-09-06T16:19:34-04:00' do
          get '/accredited_representative_portal/v0/user'

          expect(response).to have_http_status(:ok)
          expect(parsed_response).to eq(
            {
              'account' => {
                'account_uuid' => user.user_account.id
              },
              'profile' => {
                'first_name' => first_name,
                'last_name' => last_name,
                'verified' => true,
                'sign_in' => {
                  'service_name' => sign_in_service_name
                }
              },
              'prefills_available' => [],
              'in_progress_forms' => [
                {
                  'form' => in_progress_form_id,
                  'metadata' => {
                    'version' => 1,
                    'return_url' => in_progress_form_return_url,
                    'submission' => {
                      'status' => false,
                      'error_message' => false,
                      'id' => false,
                      'timestamp' => false,
                      'has_attempted_submit' => false
                    },
                    'createdAt' => Time.current.to_i,
                    'expiresAt' => 60.days.from_now.to_i,
                    'lastUpdated' => Time.current.to_i,
                    'inProgressFormId' => InProgressForm.find_by(
                      form_id: in_progress_form_id,
                      user_account_id: user.user_account.id
                    ).id
                  },
                  'lastUpdated' => Time.current.to_i
                }
              ]
            }
          )
        end
      end
    end
  end
end
