# frozen_string_literal: true

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestsPolicy do
  let(:user) { build(:representative_user, email: 'test@va.gov') }
  let(:unassociated_user) { build(:representative_user, email: 'other@va.gov') }
  let(:poa_request) do
    Struct.new(:poa_code).new('123')
  end
  let(:poa_requests) { [poa_request] }

  describe '#authorize' do
    context 'single POA request' do
      it 'errors when unassociated to user' do
        result = described_class.new(unassociated_user, poa_request).authorize
        expect(result).to be false
      end

      it 'does not error when associated to user' do
        result = described_class.new(user, poa_request).authorize
        expect(result).to be true
      end
    end

    context 'multiple POA requests' do
      it 'errors when unassociated to user' do
        result = described_class.new(unassociated_user, poa_requests).authorize
        expect(result).to be false
      end

      it 'does not error when associated to user' do
        result = described_class.new(user, poa_requests).authorize
        expect(result).to be true
      end
    end
  end
end
