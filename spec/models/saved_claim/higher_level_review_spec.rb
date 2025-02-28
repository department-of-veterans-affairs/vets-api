# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe SavedClaim::HigherLevelReview, type: :model do
  let(:guid) { SecureRandom.uuid }
  let(:form_data) do
    { stuff: 'things' }
  end
  let!(:appeal_submission) { create(:appeal_submission, type_of_appeal: 'SC', submitted_appeal_uuid: guid) }

  describe 'AppealSubmission association' do
    let!(:saved_claim_hlr) { described_class.create!(guid:, form: form_data.to_json) }

    it 'has one AppealSubmission' do
      expect(saved_claim_hlr.appeal_submission).to eq appeal_submission
    end

    it 'can be accessed from the AppealSubmission' do
      expect(appeal_submission.saved_claim_hlr).to eq saved_claim_hlr
    end
  end

  describe 'validation' do
    let!(:saved_claim_hlr) { described_class.new(guid:, form: form_data.to_json) }

    context 'no validation errors' do
      it 'returns true' do
        allow(JSON::Validator).to receive(:fully_validate).and_return([])

        expect(saved_claim_hlr.validate).to be true
      end
    end

    context 'with validation errors' do
      let(:validation_errors) { ['error', 'error 2'] }

      it 'returns true' do
        allow(JSON::Validator).to receive(:fully_validate).and_return(validation_errors)
        expect(Rails.logger).to receive(:warn).with('SavedClaim: schema validation errors detected for form 20-0996',
                                                    guid:,
                                                    count: 2)

        expect(saved_claim_hlr.validate).to be true
      end
    end

    context 'with JSON validator exception' do
      let(:exception) { JSON::Schema::ReadFailed.new('location', 'type') }

      it 'returns true' do
        allow(JSON::Validator).to receive(:fully_validate).and_raise(exception)
        expect(Rails.logger).to receive(:warn).with('SavedClaim: form_matches_schema error raised for form 20-0996',
                                                    guid:,
                                                    error: exception.message)

        expect(saved_claim_hlr.validate).to be true
      end
    end
  end
end
