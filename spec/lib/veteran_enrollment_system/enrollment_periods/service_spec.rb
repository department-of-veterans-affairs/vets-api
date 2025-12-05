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

          expect(response).to eq([
                                   { 'startDate' => '2024-03-05',
                                     'endDate' => '2024-03-05' },
                                   { 'startDate' => '2019-03-05',
                                     'endDate' => '2022-03-05' },
                                   { 'startDate' => '2010-03-05',
                                     'endDate' => '2015-03-05' }
                                 ])
        end
      end
    end

    context 'when an error status is received' do
      it 'raises a mapped error (ResourceNotFound)' do
        VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_not_found',
                         { match_requests_on: %i[method uri] }) do
          expect { subject.get_enrollment_periods(icn:) }.to raise_error(Common::Exceptions::ResourceNotFound)
        end
      end

      it 'logs and increments StatsD on error' do
        VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_not_found',
                         { match_requests_on: %i[method uri] }) do
          expect(StatsD).to receive(:increment).with('api.enrollment_periods.get_enrollment_periods.fail',
                                                     { tags: ['error:CommonExceptionsResourceNotFound'] })
          expect(StatsD).to receive(:increment).with('api.enrollment_periods.get_enrollment_periods.total')
          # expect(StatsD).to receive(:increment).with('api.enrollment_periods.get_enrollment_periods.failed')
          expect(Rails.logger).to receive(:error).with(
            /get_enrollment_periods failed: No enrollments found for the provided ICN 1014361683V924543 with tax year 2024/
          )
          expect do
            subject.get_enrollment_periods(icn:)
          end.to raise_error(Common::Exceptions::ResourceNotFound)
        end
      end
    end
  end
end
