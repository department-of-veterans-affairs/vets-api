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
          expect(response.enrollment_verifications).to eq([{ 'verification_month' => 'January 2021',
                                                             'certified_begin_date' => '2021-01-01',
                                                             'certified_end_date' => '2021-01-31',
                                                             'certified_through_date' => nil,
                                                             'certification_method' => nil,
                                                             'enrollments' => [{
                                                               'facility_name' => 'UNIVERSITY OF HAWAII AT HILO',
                                                               'begin_date' => '2020-01-01',
                                                               'end_date' => '2021-01-01',
                                                               'total_credit_hours' => 17.0
                                                             }],
                                                             'verification_response' => 'NR',
                                                             'created_date' => nil }])
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

          expect(response.status).to eq(200)
        end
      end
    end
  end
end
