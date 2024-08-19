# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::SavedClaimHlrStatusUpdaterJob, type: :job do
  subject { described_class }

  let(:service) { instance_double(DecisionReviewV1::Service) }

  let(:guid1) { SecureRandom.uuid }
  let(:guid2) { SecureRandom.uuid }
  let(:guid3) { SecureRandom.uuid }

  let(:response_complete) do
    response = JSON.parse(VetsJsonSchema::EXAMPLES.fetch('HLR-SHOW-RESPONSE-200_V2').to_json) # deep copy
    response['data']['attributes']['status'] = 'complete'
    instance_double(Faraday::Response, body: response)
  end

  let(:response_pending) do
    instance_double(Faraday::Response, body: VetsJsonSchema::EXAMPLES.fetch('HLR-SHOW-RESPONSE-200_V2'))
  end

  before do
    allow(DecisionReviewV1::Service).to receive(:new).and_return(service)
  end

  describe 'perform' do
    context 'with flag enabled', :aggregate_failures do
      before do
        Flipper.enable :decision_review_saved_claim_hlr_status_updater_job_enabled
      end

      context 'SavedClaim records are present' do
        before do
          SavedClaim::HigherLevelReview.create(guid: guid1, form: '{}')
          SavedClaim::HigherLevelReview.create(guid: guid2, form: '{}')
          SavedClaim::HigherLevelReview.create(guid: guid3, form: '{}', delete_date: DateTime.new(2024, 2, 1).utc)
          SavedClaim::SupplementalClaim.create(form: '{}')
          SavedClaim::NoticeOfDisagreement.create(form: '{}')
        end

        it 'updates SavedClaim::HigherLevelReview delete_date for completed records without a delete_date' do
          expect(service).to receive(:get_higher_level_review).with(guid1).and_return(response_complete)
          expect(service).to receive(:get_higher_level_review).with(guid2).and_return(response_pending)
          expect(service).not_to receive(:get_higher_level_review).with(guid3)

          expect(service).not_to receive(:get_notice_of_disagreement)
          expect(service).not_to receive(:get_supplemental_claim)

          frozen_time = DateTime.new(2024, 1, 1).utc

          Timecop.freeze(frozen_time) do
            subject.new.perform

            claim1 = SavedClaim::HigherLevelReview.find_by(guid: guid1)
            expect(claim1.delete_date).to eq frozen_time + 59.days
            expect(claim1.metadata).to include 'complete'
            expect(claim1.metadata_updated_at).to eq frozen_time

            claim2 = SavedClaim::HigherLevelReview.find_by(guid: guid2)
            expect(claim2.delete_date).to be_nil
            expect(claim2.metadata).to include 'pending'
            expect(claim2.metadata_updated_at).to eq frozen_time
          end
        end
      end
    end

    context 'with flag disabled' do
      before do
        Flipper.disable :decision_review_saved_claim_hlr_status_updater_job_enabled
      end

      it 'does not query SavedClaim::HigherLevelReview records' do
        expect(SavedClaim::HigherLevelReview).not_to receive(:where)

        subject.new.perform
      end
    end
  end
end
