# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::EnrollmentUploadJob, type: :worker do
  describe '#perform' do
    let(:record_count) { 42 }

    let(:batch_id) { '20210101123456' }
    let(:batched_records) do
      subs = YAML.load_file('modules/covid_vaccine/spec/fixtures/expanded_registration_submissions_upload.yml')
      subs.values.map do |s|
        FactoryBot.create(:covid_vax_expanded_registration, state: 'received', raw_form_data: s['raw_form_data'],
                                                            batch_id: batch_id)
      end
    end

    around do |example|
      Timecop.freeze(Time.zone.parse('2021-04-02T00:00:00Z'))
      example.run
      Timecop.return
    end

    context 'when batch upload succeeds' do
      before do
        allow_any_instance_of(CovidVaccine::V0::EnrollmentProcessor)
          .to receive(:process_and_upload!).and_return(batched_records.size)
      end

      it 'resolves facilities to the expected values' do
        subject.perform(batch_id)
        updated_records = CovidVaccine::V0::ExpandedRegistrationSubmission.where(batch_id: batch_id)
        expect(updated_records.map(&:eligibility_info)).to eq(
          [
            { 'preferred_facility' => nil },
            { 'preferred_facility' => '442' },
            { 'preferred_facility' => '648' }
          ]
        )
      end

      it 'logs its progress' do
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Enrollment_Upload: Start', batch_id: batch_id)
        expect(Rails.logger).to receive(:info).with(
          'Covid_Vaccine Enrollment_Upload: Updated mapped facility info', batch_id: batch_id,
                                                                           record_count: batched_records.size
        )
        expect(Rails.logger).to receive(:info).with(
          'Covid_Vaccine Enrollment_Upload: Success', batch_id: batch_id, record_count: batched_records.size
        )

        expect(StatsD).to receive(:increment).once.with('worker.covid_vaccine_enrollment_upload.success')

        VCR.use_cassette('covid_vaccine/facilities/query_46953', match_requests_on: %i[path query]) do
          VCR.use_cassette('covid_vaccine/facilities/query_27330', match_requests_on: %i[path query]) do
            subject.perform(batch_id)
          end
        end
      end
    end

    context 'when processing fails' do
      before do
        allow(CovidVaccine::V0::ExpandedRegistrationSubmission).to receive(:where).and_raise(
          ActiveRecord::ActiveRecordError
        )
      end

      it 'logs its progress and raises the original error' do
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Enrollment_Upload: Start', batch_id: batch_id)
        expect(Rails.logger).to receive(:error).with('Covid_Vaccine Enrollment_Upload: Failed',
                                                     batch_id: batch_id).ordered.and_call_original
        expect(Rails.logger).to receive(:error).at_least(:once).with(instance_of(String)).ordered # backtrace line

        expect(StatsD).to receive(:increment).once.with('worker.covid_vaccine_enrollment_upload.error')

        expect { subject.perform(batch_id) }.to raise_error(StandardError)
      end
    end
  end
end
