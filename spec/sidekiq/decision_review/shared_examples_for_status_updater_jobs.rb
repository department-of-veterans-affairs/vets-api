# frozen_string_literal: true

require 'rails_helper'

SUBCLASS_INFO = {
  SavedClaim::SupplementalClaim => { service_method: 'get_supplemental_claim',
                                     evidence_service_method: 'get_supplemental_claim_upload',
                                     statsd_prefix: 'worker.decision_review.saved_claim_sc_status_updater',
                                     log_prefix: 'DecisionReview::SavedClaimScStatusUpdaterJob',
                                     service_tag: 'service:supplemental-claims' },
  SavedClaim::HigherLevelReview => { service_method: 'get_higher_level_review',
                                     evidence_service_method: nil,
                                     statsd_prefix: 'worker.decision_review.saved_claim_hlr_status_updater',
                                     log_prefix: 'DecisionReview::SavedClaimHlrStatusUpdaterJob',
                                     service_tag: 'service:higher-level-review' },
  SavedClaim::NoticeOfDisagreement => { service_method: 'get_notice_of_disagreement',
                                        evidence_service_method: 'get_notice_of_disagreement_upload',
                                        statsd_prefix: 'worker.decision_review.saved_claim_nod_status_updater',
                                        log_prefix: 'DecisionReview::SavedClaimNodStatusUpdaterJob',
                                        service_tag: 'service:board-appeal' }
}.freeze

RSpec.shared_context 'status updater job context' do |subclass|
  subject { described_class }

  let(:service) { instance_double(DecisionReviewV1::Service) }

  let(:guid1) { SecureRandom.uuid }
  let(:guid2) { SecureRandom.uuid }
  let(:guid3) { SecureRandom.uuid }
  let(:other_subclass1) { SUBCLASS_INFO.keys.excluding(subclass)[0] }
  let(:other_subclass2) { SUBCLASS_INFO.keys.excluding(subclass)[1] }
  let(:service_method) { SUBCLASS_INFO[subclass][:service_method].to_sym }
  let(:other_service_method1) { SUBCLASS_INFO[other_subclass1][:service_method].to_sym }
  let(:other_service_method2) { SUBCLASS_INFO[other_subclass2][:service_method].to_sym }

  let(:statsd_prefix) { SUBCLASS_INFO[subclass][:statsd_prefix] }
  let(:log_prefix) { SUBCLASS_INFO[subclass][:log_prefix] }
  let(:service_tag) { SUBCLASS_INFO[subclass][:service_tag] }

  let(:response_complete) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('HLR-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'complete'
    instance_double(Faraday::Response, body: response)
  end

  let(:response_pending) do
    instance_double(Faraday::Response, body: VetsJsonSchema::EXAMPLES.fetch('HLR-SHOW-RESPONSE-200_V2'))
  end

  let(:response_error) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('SC-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'error'
    instance_double(Faraday::Response, body: response)
  end

  before do
    allow(DecisionReviewV1::Service).to receive(:new).and_return(service)
    allow(StatsD).to receive(:increment)
  end
end

RSpec.shared_examples 'status updater job with base forms' do |subclass|
  context 'SavedClaim records are present' do
    before do
      subclass.create(guid: guid1, form: '{}')
      subclass.create(guid: guid2, form: '{}')
      subclass.create(guid: guid3, form: '{}', delete_date: DateTime.new(2024, 2, 1).utc)
      other_subclass1.create(form: '{}')
      other_subclass2.create(form: '{}')
    end

    it 'updates delete_date for completed records of the subclass without a delete_date' do
      expect(service).to receive(service_method).with(guid1).and_return(response_complete)
      expect(service).to receive(service_method).with(guid2).and_return(response_pending)
      expect(service).not_to receive(service_method).with(guid3)

      expect(service).not_to receive(other_service_method1)
      expect(service).not_to receive(other_service_method2)

      frozen_time = DateTime.new(2024, 1, 1).utc

      Timecop.freeze(frozen_time) do
        subject.new.perform

        claim1 = subclass.find_by(guid: guid1)
        expect(claim1.delete_date).to eq frozen_time + 59.days
        expect(claim1.metadata).to include 'complete'
        expect(claim1.metadata_updated_at).to eq frozen_time

        claim2 = subclass.find_by(guid: guid2)
        expect(claim2.delete_date).to be_nil
        expect(claim2.metadata).to include 'pending'
        expect(claim2.metadata_updated_at).to eq frozen_time

        expect(StatsD).to have_received(:increment)
          .with("#{statsd_prefix}.processing_records", 2).exactly(1).time
        expect(StatsD).to have_received(:increment)
          .with("#{statsd_prefix}.delete_date_update").exactly(1).time
        expect(StatsD).to have_received(:increment)
          .with("#{statsd_prefix}.status", tags: ['status:pending'])
          .exactly(1).time
      end
    end

    it 'handles request errors and increments the statsd metric' do
      allow(service).to receive(service_method).and_raise(DecisionReviewV1::ServiceException)

      subject.new.perform

      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}.error").exactly(2).times
    end
  end

  context 'SavedClaim record with previous metadata' do
    before do
      subclass.create(guid: guid1, form: '{}', metadata: '{"status":"error"}')
      subclass.create(guid: guid2, form: '{}', metadata: '{"status":"submitted"}')
      subclass.create(guid: guid3, form: '{}', metadata: '{"status":"pending"}')
      allow(Rails.logger).to receive(:info)
    end

    it 'does not increment metrics for unchanged form status' do
      expect(service).to receive(service_method).with(guid1).and_return(response_error)
      expect(service).to receive(service_method).with(guid2).and_return(response_error)
      expect(service).to receive(service_method).with(guid3).and_return(response_pending)

      subject.new.perform

      claim1 = subclass.find_by(guid: guid1)
      expect(claim1.delete_date).to be_nil
      expect(claim1.metadata).to include 'error'

      claim2 = subclass.find_by(guid: guid2)
      expect(claim2.delete_date).to be_nil
      expect(claim2.metadata).to include 'error'

      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}.status", tags: ['status:error'])
        .exactly(1).time
      expect(StatsD).not_to have_received(:increment)
        .with("#{statsd_prefix}.status", tags: ['status:pending'])

      expect(Rails.logger).not_to have_received(:info)
        .with("#{log_prefix} form status error", guid: guid1)
      expect(Rails.logger).to have_received(:info)
        .with("#{log_prefix} form status error", guid: guid2)
      expect(StatsD).to have_received(:increment)
        .with('silent_failure', tags: [service_tag,
                                       'function: form submission to Lighthouse'])
        .exactly(1).time
    end
  end

  context 'Retrieving SavedClaim records fails' do
    before do
      allow(subclass).to receive(:where).and_raise(ActiveRecord::ConnectionTimeoutError)
      allow(Rails.logger).to receive(:error)
    end

    it 'rescues the error and logs' do
      subject.new.perform

      expect(Rails.logger).to have_received(:error)
        .with("#{log_prefix} error", anything)
      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}.error").once
    end
  end

  context 'an error occurs while processing form, attachments, or secondary form' do
    before do
      subclass.create(guid: SecureRandom.uuid, form: '{}')
      subclass.create(guid: SecureRandom.uuid, form: '{}')
    end

    it 'handles request errors and increments the statsd metric' do
      allow(service).to receive(service_method).and_raise(DecisionReviewV1::ServiceException)

      subject.new.perform

      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}.error").exactly(2).times
    end
  end
end

RSpec.shared_examples 'status updater job when forms include evidence' do |subclass|
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

  let(:evidence_service_method) { SUBCLASS_INFO[subclass][:evidence_service_method].to_sym}

  context 'SavedClaim records are present with completed status in LH and have associated evidence uploads' do
    let(:upload_id) { SecureRandom.uuid }
    let(:upload_id2) { SecureRandom.uuid }
    let(:upload_id3) { SecureRandom.uuid }
    let(:upload_id4) { SecureRandom.uuid }

    before do
      allow(Rails.logger).to receive(:info)

      subclass.create(guid: guid1, form: '{}')
      subclass.create(guid: guid2, form: '{}')
      subclass.create(guid: guid3, form: '{}')

      appeal_submission = create(:appeal_submission, submitted_appeal_uuid: guid1)
      create(:appeal_submission_upload, appeal_submission:, lighthouse_upload_id: upload_id)

      appeal_submission2 = create(:appeal_submission, submitted_appeal_uuid: guid2)
      create(:appeal_submission_upload, appeal_submission: appeal_submission2, lighthouse_upload_id: upload_id2)

      # One upload vbms, other one still processing
      appeal_submission3 = create(:appeal_submission, submitted_appeal_uuid: guid3)
      create(:appeal_submission_upload, appeal_submission: appeal_submission3, lighthouse_upload_id: upload_id3)
      create(:appeal_submission_upload, appeal_submission: appeal_submission3, lighthouse_upload_id: upload_id4)
    end

    it 'only sets delete_date for subclass with all attachments in vbms status' do
      expect(service).to receive(evidence_service_method).with(guid: upload_id)
                                                                    .and_return(upload_response_vbms)
      expect(service).to receive(evidence_service_method).with(guid: upload_id2)
                                                                    .and_return(upload_response_processing)
      expect(service).to receive(evidence_service_method).with(guid: upload_id3)
                                                                    .and_return(upload_response_vbms)
      expect(service).to receive(evidence_service_method).with(guid: upload_id4)
                                                                    .and_return(upload_response_processing)

      expect(service).to receive(service_method).with(guid1).and_return(response_complete)
      expect(service).to receive(service_method).with(guid2).and_return(response_complete)
      expect(service).to receive(service_method).with(guid3).and_return(response_complete)

      frozen_time = DateTime.new(2024, 1, 1).utc

      Timecop.freeze(frozen_time) do
        subject.new.perform

        claim1 = subclass.find_by(guid: guid1)
        expect(claim1.delete_date).to eq frozen_time + 59.days
        expect(claim1.metadata_updated_at).to eq frozen_time
        expect(claim1.metadata).to include 'complete'
        expect(claim1.metadata).to include 'vbms'

        claim2 = subclass.find_by(guid: guid2)
        expect(claim2.delete_date).to be_nil
        expect(claim2.metadata_updated_at).to eq frozen_time
        expect(claim2.metadata).to include 'complete'
        expect(claim2.metadata).to include 'processing'

        claim3 = subclass.find_by(guid: guid3)
        expect(claim3.delete_date).to be_nil
        expect(claim3.metadata_updated_at).to eq frozen_time

        metadata3 = JSON.parse(claim3.metadata)
        expect(metadata3['status']).to eq 'complete'
        expect(metadata3['uploads'].pluck('id', 'status'))
          .to contain_exactly([upload_id3, 'vbms'], [upload_id4, 'processing'])
      end

      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}.processing_records", 3).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}.delete_date_update").exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}.status", tags: ['status:complete'])
        .exactly(2).times
      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}_upload.status", tags: ['status:vbms'])
        .exactly(2).times
      expect(StatsD).to have_received(:increment)
        .with("#{statsd_prefix}_upload.status", tags: ['status:processing'])
        .exactly(2).times
      expect(Rails.logger).not_to have_received(:info)
        .with("#{log_prefix} evidence status error", anything)
    end
  end
end
