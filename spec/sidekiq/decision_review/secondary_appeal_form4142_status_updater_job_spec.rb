# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::SecondaryAppealForm4142StatusUpdaterJob, type: :job do
  context 'when the feature is eneabled' do
    context 'when there are SecondaryAppealForm records of type 4142' do
      let(:service) { instance_double(DecisionReviewV1::Service) }

      let!(:form1) { create(:secondary_appeal_form4142, guid: SecureRandom.uuid) }
      let!(:form2) { create(:secondary_appeal_form4142, guid: SecureRandom.uuid) }
      let!(:form3) { create(:secondary_appeal_form4142, guid: SecureRandom.uuid) }
      let!(:form_with_delete_date) do
        create(:secondary_appeal_form4142, guid: SecureRandom.uuid, delete_date: 10.days.from_now)
      end
      let!(:other_form_type) do
        SecondaryAppealForm.create(form_id: 'Other', guid: SecureRandom.uuid, form: { stuff: 'things' }.to_json)
      end

      let(:upload_response_vbms) do
        response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_upload_show_response_200.json'))
        instance_double(Faraday::Response, body: response)
      end

      let(:upload_response_processing) do
        response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_upload_show_response_200.json'))
        response['data']['attributes']['status'] = 'processing'
        instance_double(Faraday::Response, body: response)
      end

      let(:upload_response_error) do
        response = JSON.parse(File.read('spec/fixtures/supplemental_claims/SC_upload_show_response_200.json'))
        response['data']['attributes']['status'] = 'error'
        response['data']['attributes']['detail'] = 'Invalid PDF'
        instance_double(Faraday::Response, body: response)
      end

      before do
        allow(DecisionReviewV1::Service).to receive(:new).and_return(service)
        allow(service).to receive(:get_supplemental_claim_upload)
          .with(uuid: form1.guid).and_return(upload_response_vbms)
        allow(service).to receive(:get_supplemental_claim_upload)
          .with(uuid: form2.guid).and_return(upload_response_processing)
        allow(service).to receive(:get_supplemental_claim_upload)
          .with(uuid: form3.guid).and_return(upload_response_error)
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:info)
      end

      it 'does NOT check status for records that already have a delete_date' do
        expect(service).to receive(:get_supplemental_claim_upload).with(uuid: form1.guid)
        expect(service).to receive(:get_supplemental_claim_upload).with(uuid: form2.guid)
        expect(service).to receive(:get_supplemental_claim_upload).with(uuid: form3.guid)
        expect(service).not_to receive(:get_supplemental_claim_upload).with(uuid: form_with_delete_date.guid)
        subject.perform
      end

      it 'does NOT check status for records that are not a 4142' do
        expect(service).to receive(:get_supplemental_claim_upload).with(uuid: form1.guid)
        expect(service).to receive(:get_supplemental_claim_upload).with(uuid: form2.guid)
        expect(service).to receive(:get_supplemental_claim_upload).with(uuid: form3.guid)
        expect(service).not_to receive(:get_supplemental_claim_upload).with(uuid: other_form_type.guid)
        subject.perform
      end

      context 'updating information' do
        let(:frozen_time) { DateTime.new(2024, 1, 1).utc }

        it 'updates the status and sets delete_date if appropriate' do
          Timecop.freeze(frozen_time) do
            subject.perform
          end
          expect(form1.reload.status).to include('vbms')
          expect(form1.reload.status_updated_at).to eq frozen_time
          expect(form1.reload.delete_date).to eq frozen_time + 59.days

          expect(form2.reload.status).to include('processing')
          expect(form2.reload.status_updated_at).to eq frozen_time
          expect(form2.reload.delete_date).to be_nil

          expect(form3.reload.status).to include('error')
          expect(form3.reload.status_updated_at).to eq frozen_time
          expect(form3.reload.delete_date).to be_nil
        end

        it 'logs updates to the status' do
          Timecop.freeze(frozen_time) do
            subject.perform
          end

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.secondary_appeal_form4142_status_updater.processing_records', 3).exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.secondary_appeal_form4142_status_updater.delete_date_update').exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.secondary_appeal_form4142_status_updater.status', tags: ['status:vbms'])
            .exactly(1).time
          expect(StatsD).to have_received(:increment)
            .with('worker.decision_review.secondary_appeal_form4142_status_updater.status', tags: ['status:processing'])
            .exactly(1).time

          expect(Rails.logger).to have_received(:info)
            .with('DecisionReview::SecondaryAppealForm4142StatusUpdaterJob status error', anything)
          expect(StatsD).to have_received(:increment)
            .with('silent_failure', tags: ['service:supplemental-claims-4142',
                                           'function: PDF submission to Lighthouse'])
            .exactly(1).time
        end

        context 'when the status is unchanged' do
          before do
          end

          it 'does not log a change'
        end

        context 'an error occurs during processing' do
          it 'logs the error'
        end
      end
    end
  end
end
