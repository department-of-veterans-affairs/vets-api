# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/enrollment_periods/service'

RSpec.describe VeteranEnrollmentSystem::EnrollmentPeriods::Service do
  let(:icn) { '1012667145V762142' }

  describe '#get_enrollment_periods' do
    context 'when the request is successful' do
      it 'returns the enrollment periods' do
        VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_success',
                         { match_requests_on: %i[method uri] }) do
          response = subject.get_enrollment_periods(icn:)

          expect(response).to eq(
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
