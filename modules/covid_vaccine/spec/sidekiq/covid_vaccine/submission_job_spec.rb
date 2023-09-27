# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::SubmissionJob, type: :worker do
  subject { described_class.new }

  describe '#perform' do
    let(:pending_submission) { create(:covid_vax_registration, :unsubmitted) }
    let(:user_type) { 'loa3' }
    let(:expected_attributes) do
      %w[vaccine_interest zip_code time_at_zip phone email first_name last_name
         date_of_birth patient_ssn zip_lat zip_lon sta3n authenticated]
    end

    it 'updates the submission object' do
      VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_loa3', match_requests_on: %i[method path]) do
        VCR.use_cassette('covid_vaccine/facilities/query_97212', match_requests_on: %i[method path]) do
          subject.perform(pending_submission.id, user_type)
          pending_submission.reload
          expect(pending_submission.sid).to be_truthy
          expect(pending_submission.form_data).to be_truthy
          expect(pending_submission.form_data).to include(*expected_attributes)
        end
      end
    end

    describe 'with vetext failure' do
      it 'raises an error' do
        with_settings(Settings.sentry, dsn: 'T') do
          VCR.use_cassette('covid_vaccine/facilities/query_97212', match_requests_on: %i[method path]) do
            expect(Raven).to receive(:capture_exception)
            expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
              .and_raise(Common::Exceptions::BackendServiceException, 'VA900')
            expect { subject.perform(pending_submission.id, user_type) }.to raise_error(StandardError)
          end
        end
      end

      it 'leaves submission unmodified' do
        VCR.use_cassette('covid_vaccine/facilities/query_97212', match_requests_on: %i[method path]) do
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .and_raise(Common::Exceptions::BackendServiceException, 'VA900')
          expect { subject.perform(pending_submission.id, user_type) }.to raise_error(StandardError)
          pending_submission.reload
          expect(pending_submission.sid).to be_nil
          expect(pending_submission.form_data).to be_nil
        end
      end
    end

    it 'raises an error if submission is missing' do
      with_settings(Settings.sentry, dsn: 'T') do
        expect(Raven).to receive(:capture_exception)
        expect { subject.perform('fakeid', user_type) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
