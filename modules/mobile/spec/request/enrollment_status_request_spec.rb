# frozen_string_literal: true

require_relative '../support/helpers/rails_helper'

RSpec.describe 'enrollment status', type: :request do
  let!(:user) { sis_user }

  describe 'GET /mobile/v0/enrollment-status' do
    let(:success_response) do
      {
        application_date: '2018-01-24T00:00:00.000-06:00',
        enrollment_date: nil,
        preferred_facility: '987 - CHEY6',
        parsed_status: HCA::EnrollmentEligibility::Constants::INELIG_CHARACTER_OF_DISCHARGE.to_s,
        primary_eligibility: 'SC LESS THAN 50%',
        can_submit_financial_info: true
      }
    end

    context 'when user is enrolled' do
      it 'returns enrolled with 200 status' do
        expect(HealthCareApplication).to receive(:enrollment_status).with(
          user.icn, true
        ).and_return(success_response)
        get('/mobile/v0/enrollment-status', headers: sis_headers)

        expect(response).to have_http_status(:ok)
        expected_attributes = success_response.transform_keys { |key| key.to_s.camelize(:lower) }
        expect(response.parsed_body.dig('data', 'attributes')).to match(expected_attributes)
      end
    end

    context 'when user is not enrolled' do

    end
  end
end