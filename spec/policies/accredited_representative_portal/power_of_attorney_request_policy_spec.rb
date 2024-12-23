# frozen_string_literal: true

require 'rails_helper'

describe AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy do
  subject { described_class }

  let(:user) { build(:user, :loa3, email: 'test@va.gov') }

  describe AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy::Scope do
    subject { described_class }

    it 'returns the scope of mock data' do
      expect(subject.new(user, nil).resolve).to eq AccreditedRepresentativePortal::POA_REQUEST_LIST_MOCK_DATA
    end
  end

  permissions :show? do
    context 'with allowed user' do
      it 'permits show' do
        expect(subject).to permit(user, { attributes: { powerOfAttorneyCode: '123' } })
      end
    end

    context 'with disallowed user' do
      let(:user) { build(:user, :loa3, email: 'j3@example.com') }

      it 'denies access' do
        expect(subject).not_to permit(user, OpenStruct.new(poa_code: '123'))
      end
    end
  end
end
