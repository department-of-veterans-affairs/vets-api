# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/enrollment_periods/service'

RSpec.describe VeteranEnrollmentSystem::EnrollmentPeriods::Service do
  let(:icn) { '1012667145V762142' }

  describe '#get_enrollment_periods' do
    context 'when the request is successful' do
      it 'returns the form data from the enrollment system' do
        VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_success',
                         { match_requests_on: %i[method uri] }) do
          response = subject.get_enrollment_periods(icn:)

          expect(response).to eq(
            {
              'data' => {
                'icn' => '1012667122V019349',
                'mecPeriods' => [
                  {
                    'startDate' => '2024-03-05',
                    'endDate' => '2024-03-05'
                  }
                ]
              },
              'messages' => []
            }
          )
        end
      end
    end

    context 'when an error status is received' do
      it 'raises an error' do
        VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_not_found',
                         { match_requests_on: %i[method uri] }) do
          expect { subject.get_enrollment_periods(icn:) }.to raise_error(Common::Client::Errors::ClientError)
        end
      end
    end
  end
end
