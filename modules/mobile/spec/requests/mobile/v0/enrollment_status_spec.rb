# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::EnrollmentStatus', type: :request do
  let!(:user) { sis_user }

  describe 'GET /mobile/v0/enrollment-status' do
    context 'with an loa3 user' do
      context 'and status is enrolled' do
        it 'returns ok with enrolled status' do
          VCR.use_cassette('hca/ee/lookup_user', erb: true) do
            get('/mobile/v0/enrollment-status', headers: sis_headers)
          end

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to match(
            {
              data: {
                id: user.uuid,
                type: 'enrollment_status',
                attributes: {
                  status: 'enrolled'
                }
              }
            }
          )
        end
      end

      context 'and status is pending' do
        let(:pending_response) do
          {
            application_date: '2018-01-24T00:00:00.000-06:00',
            enrollment_date: nil,
            preferred_facility: '987 - CHEY6',
            parsed_status: HCA::EnrollmentEligibility::Constants::PENDING_MT,
            primary_eligibility: 'SC LESS THAN 50%',
            can_submit_financial_info: true
          }
        end

        it 'returns ok with pending status' do
          # stubbing because no cassettes exist for this use case
          expect(HealthCareApplication).to receive(:enrollment_status).with(
            user.icn, true
          ).and_return(pending_response)
          get('/mobile/v0/enrollment-status', headers: sis_headers)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to match(
            {
              data: {
                id: user.uuid,
                type: 'enrollment_status',
                attributes: {
                  status: 'pending'
                }
              }
            }
          )
        end
      end

      context 'and status is other' do
        it 'returns ok with other status' do
          VCR.use_cassette('hca/ee/lookup_user_ineligibility_reason', erb: true) do
            get('/mobile/v0/enrollment-status', headers: sis_headers)
          end

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to match(
            {
              data: {
                id: user.uuid,
                type: 'enrollment_status',
                attributes: {
                  status: 'other'
                }
              }
            }
          )
        end
      end
    end

    context 'with a non-loa3 user' do
      let!(:user) { sis_user(:api_auth, :loa1) }

      it 'returns unauthorized' do
        get('/mobile/v0/enrollment-status', headers: sis_headers)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user has no icn' do
      let!(:user) { sis_user(:api_auth, icn: nil) }

      it 'returns not found' do
        get('/mobile/v0/enrollment-status', headers: sis_headers)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
