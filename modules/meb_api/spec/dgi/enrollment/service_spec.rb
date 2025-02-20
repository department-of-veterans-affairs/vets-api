# frozen_string_literal: true

require 'rails_helper'
require 'dgi/enrollment/service'

RSpec.describe MebApi::DGI::Enrollment::Service do
  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end
    let(:user) { create(:user, :loa3) }
    let(:service) { MebApi::DGI::Enrollment::Service.new(user) }
    let(:enrollment_verification_params) do
      { enrollment_verifications: {
        enrollment_certify_requests: [{
          certified_period_begin_date: '2022-08-01',
          certified_period_end_date: '2022-08-31',
          certified_through_date: '2022-08-31',
          certification_method: 'MEB',
          app_communication: { response_type: 'Y' }
        }]
      } }
    end

    describe '#get_enrollment' do
      let(:faraday_response) { double('faraday_connection') }

      before do
        allow(faraday_response).to receive(:env)
      end

      context 'when successful' do
        it 'returns a status of 200' do
          VCR.use_cassette('dgi/enrollment') do
            response = service.get_enrollment(600_000_000)
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
            response = service.submit_enrollment(ActionController::Parameters.new(enrollment_verification_params),
                                                 123_456)

            expect(response.status).to eq(200)
          end
        end
      end
    end
  end
end
