# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestsPolicy do
  let(:user) { build(:representative_user, email: 'test@va.gov') }
  let(:unassociated_user) { build(:representative_user, email: 'other@va.gov') }
  let(:poa_request) do
    Struct.new(:poa_code).new('123')
  end
  let(:poa_requests) { [poa_request] }

  before do
    allow_any_instance_of(described_class).to receive(:pilot_user_email_poa_codes)
      .and_return({ 'test@va.gov' => ['123'] })
  end

  describe '#authorize' do
    context 'single POA request' do
      it 'errors when unassociated to user' do
        result = described_class.new(unassociated_user, poa_request).send(:authorize)
        expect(result).to be false
      end

      it 'does not error when associated to user' do
        result = described_class.new(user, poa_request).send(:authorize)
        expect(result).to be true
      end
    end

    context 'multiple POA requests' do
      it 'errors when unassociated to user' do
        result = described_class.new(unassociated_user, poa_requests).send(:authorize)
        expect(result).to be false
      end

      it 'does not error when associated to user' do
        result = described_class.new(user, poa_requests).send(:authorize)
        expect(result).to be true
      end
    end
  end

  describe '#show?' do
    context 'single POA request' do
      it 'returns false when unassociated to user' do
        policy = described_class.new(unassociated_user, poa_request)
        expect(policy.show?).to be false
      end

      it 'returns true when associated to user' do
        policy = described_class.new(user, poa_request)
        expect(policy.show?).to be true
      end
    end
  end

  describe '#index?' do
    context 'multiple POA requests' do
      it 'returns false when unassociated to user' do
        policy = described_class.new(unassociated_user, poa_requests)
        expect(policy.index?).to be false
      end

      it 'returns true when associated to user' do
        policy = described_class.new(user, poa_requests)
        expect(policy.index?).to be true
      end
    end
  end
end
