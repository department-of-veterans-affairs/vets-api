# frozen_string_literal: true

require 'rails_helper'

describe EVSSClaimsRedisHelper do
  let(:user) { build(:user, :loa3) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }

  context 'with valid arguments' do
    subject { described_class.new(user_uuid: user.uuid, claim_id: claim.id) }

    %i[find_collection find_one].each do |method|
      describe "##{method}" do
        it 'retrieves from redis' do
          expect(subject.redis_namespace).to receive(:get).once
          subject.send(method.to_sym)
        end
      end
    end

    %i[cache_collection cache_one].each do |method|
      describe "##{method}" do
        it 'writes to redis' do
          expect(subject.redis_namespace).to receive(:set).once
          subject.send(method.to_sym, {})
        end
      end
    end
  end

  context 'without valid arguments' do
    it 'raises exception upon initialization without user uuid' do
      expect { described_class.new({}).find_collection }.to raise_error(ArgumentError)
    end

    it 'raises exception when attempting single record methods without a claim_id' do
      expect { described_class.new(user_uuid: 111).find_one }.to raise_error(ArgumentError)
    end
  end
end
