# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::EnrollmentUploadJob, type: :worker do
  describe '#perform' do
    let(:batch_id) { '20210101123456' }
    let(:record_count) { 42 }

    context 'when batch creation succeeds' do
      before do
        allow_any_instance_of(CovidVaccine::V0::EnrollmentProcessor).to receive(:process_and_upload!).and_return(42)
      end

      it 'logs its progress' do
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Enrollment_Upload: Start', batch_id:)
        expect(Rails.logger).to receive(:info).with(
          'Covid_Vaccine Enrollment_Upload: Success', batch_id:, record_count:
        )

        expect(StatsD).to receive(:increment).once.with('worker.covid_vaccine_enrollment_upload.success')

        subject.perform(batch_id)
      end
    end

    context 'when processing fails' do
      before do
        allow_any_instance_of(CovidVaccine::V0::EnrollmentProcessor).to receive(:process_and_upload!).and_raise(
          StandardError
        )
      end

      it 'logs its progress and raises the original error' do
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Enrollment_Upload: Start', batch_id:)
        expect(Rails.logger).to receive(:error).with('Covid_Vaccine Enrollment_Upload: Failed',
                                                     batch_id:).ordered.and_call_original
        expect(Rails.logger).to receive(:error).at_least(:once).with(instance_of(String)).ordered # backtrace line

        expect(StatsD).to receive(:increment).once.with('worker.covid_vaccine_enrollment_upload.error')

        expect { subject.perform(batch_id) }.to raise_error(StandardError)
      end
    end
  end
end
