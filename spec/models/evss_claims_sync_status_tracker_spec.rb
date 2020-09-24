# frozen_string_literal: true

require 'rails_helper'

describe EVSSClaimsSyncStatusTracker do
  let(:user) { build(:user, :loa3) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }

  context 'with valid arguments' do
    subject { described_class.create(user_uuid: user.uuid, claim_id: claim.id) }

    %i[collection single].each do |method|
      describe "'#{method}' set/delete" do
        it 'writes to redis' do
          expect(subject.redis_namespace).to receive(:set).twice
          subject.send("set_#{method}_status", 'RANDOM_STATUS')
          subject.send("delete_#{method}_status")
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
