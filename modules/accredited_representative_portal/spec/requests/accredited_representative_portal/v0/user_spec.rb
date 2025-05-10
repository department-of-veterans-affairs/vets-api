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
        first_name = Faker::Name.first_name
        last_name = Faker::Name.last_name
        sign_in_service_name = Faker::Company.name
        in_progress_form_id = Faker::Form.id

        let(:user) do
          create(
            :representative_user,
            :with_in_progress_form,
            {
              first_name:, last_name:,
              sign_in_service_name:,
              in_progress_form_id:
            }
          )
        end

        around do |example|
          travel_to '2024-09-06T16:19:34-04:00'
          example.run
          travel_back
        end

        it 'responds with the user and their in progress form' do
          get '/accredited_representative_portal/v0/user'

          expect(response).to have_http_status(:ok)
          expect(parsed_response).to eq(
            {
              'account' => {
                'accountUuid' => user.user_account.id
              },
              'profile' => {
                'firstName' => first_name,
                'lastName' => last_name,
                'verified' => true,
                'loa' => {
                  'current' => user.loa[:current],
                  'highest' => user.loa[:highest]
                },
                'signIn' => {
                  'serviceName' => sign_in_service_name
                }
              },
              'prefillsAvailable' => [],
              'inProgressForms' => [
                {
                  'form' => in_progress_form_id,
                  'metadata' => {
                    'version' => 1,
                    'returnUrl' => 'foo.com',
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

      context 'with different LOA values' do
        first_name = Faker::Name.first_name
        last_name = Faker::Name.last_name
        sign_in_service_name = Faker::Company.name
        current_loa = 1
        highest_loa = 2

        let(:user) do
          create(
            :representative_user,
            {
              first_name:,
              last_name:,
              sign_in_service_name:,
              loa: { current: current_loa, highest: highest_loa }
            }
          )
        end

        it 'includes loa object with current and highest values in the response' do
          get '/accredited_representative_portal/v0/user'

          expect(response).to have_http_status(:ok)
          expect(parsed_response.dig('profile', 'loa')).to eq(
            {
              'current' => current_loa,
              'highest' => highest_loa
            }
          )
        end
      end
    end
  end
end
