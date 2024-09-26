# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::SubmissionJobClaim, type: :model do
  let(:namespace) { REDIS_CONFIG[:form_1010_cg_submission_job_claim][:namespace] }
  let(:claim_id) { SecureRandom.uuid }
  let(:full_key) { "#{namespace}:#{claim_id}" }

  describe '.set_claim_key' do
    subject do
      described_class.set_claim_key(claim_id)
    end

    context 'when the key does not exist' do
      it 'sets the claim key in Redis' do
        expect($redis).not_to exist(full_key)

        subject

        expect($redis).to exist(full_key)
        expect($redis.get(full_key)).to eq('t')
      end
    end

    context 'when the key already exists' do
      it 'does not overwrite the existing key' do
        $redis.set(full_key, 'existing_value')
        expect($redis.get(full_key)).to eq('existing_value')
        subject
        expect($redis.get(full_key)).to eq('existing_value')
      end
    end
  end
end
