# frozen_string_literal: true

require 'rails_helper'

describe EVSSClaimsSyncStatusTracker do
  let(:user) { build(:user, :loa3) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }

  context 'with valid arguments' do
    subject { described_class.new(user_uuid: user.uuid, claim_id: claim.id) }

    %i[get_collection_status get_single_status].each do |method|
      describe "##{method}" do
        it 'retrieves from redis' do
          expect(subject.redis_namespace).to receive(:get).once
          subject.send(method.to_sym)
        end
      end
    end

    %i[set_collection_status set_single_status].each do |method|
      describe "##{method}" do
        it 'writes to redis' do
          expect(subject.redis_namespace).to receive(:set).once
          subject.send(method.to_sym, 'RANDOM_STATUS')
        end
      end
    end

    %i[delete_collection_status delete_single_status].each do |method|
      describe "##{method}" do
        it 'deletes from redis' do
          expect(subject.redis_namespace).to receive(:del).once
          subject.send(method.to_sym)
        end
      end
    end
  end

  context 'without valid arguments' do
    it 'raises exception upon initialization without user uuid' do
      expect { described_class.new({}).get_collection_status }.to(
        raise_error(Common::Exceptions::InternalServerError)
      )
    end

    it 'raises exception when attempting single record methods without a claim_id' do
      expect { described_class.new(user_uuid: 111).get_single_status }.to(
        raise_error(Common::Exceptions::InternalServerError)
      )
    end
  end
end
