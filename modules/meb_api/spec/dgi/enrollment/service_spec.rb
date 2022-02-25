# frozen_string_literal: true

require 'rails_helper'
require 'dgi/enrollment/service'

RSpec.describe MebApi::DGI::Enrollment::Service do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { MebApi::DGI::Enrollment::Service.new(user) }
  let(:enrollment_verification_params) do
    {
      claimant_id: 1,
      enrollments: [
        {
          "month": 'August',
          "credit_hours": 60,
          "start_date": '2022-02-15',
          "end_date": '2022-04-15'
        }
      ]
    }
  end

  describe '#get_enrollment' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/enrollment') do
          response = service.get_enrollment(1)
          expect(response.enrollment).to eq([{ 'enrollment_id' => 11 }, { 'enrollment_id' => 22 },
                                             { 'enrollment_id' => 33 }])
        end
      end
    end
  end

  describe '#submit_enrollment_verification' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('dgi/submit_enrollment_verification') do
          response = service.submit_enrollment(ActionController::Parameters.new(enrollment_verification_params))
          expect(response.enrollment).to eq([['claimant_id', 1],
                                             ['enrollments',
                                              [{ 'month' => 'August', 'credit_hours' => 60,
                                                 'start_date' => '2022-02-15', 'end_date' => '2022-04-15' }]]])
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
