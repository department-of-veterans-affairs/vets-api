# frozen_string_literal: true

require 'rails_helper'

describe AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy do
  subject { described_class }
  let(:user) { build(:user, :loa3, email: 'j2@example.com') }

  before do
    allow(Settings).to receive_message_chain(
      :accredited_representative_portal, :pilot_user_email_poa_codes
    ).and_return({ "j2@example.com" => ["123"] })
  end

  describe AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy::Scope do
    subject { described_class }

    it 'returns the scope of mock data' do
      expect(subject.new(user, nil).resolve).to eq ::AccreditedRepresentativePortal::POA_REQUEST_LIST_MOCK_DATA
    end
  end

  permissions :show? do
    context 'with allowed user' do
      it 'permits show' do
        expect(subject).to permit(user, OpenStruct.new(poa_code: '123'))
      end
    end

    context 'with disallowed user' do
      let(:user) { build(:user, :loa3, email: 'j3@example.com') }

      it 'denies access' do
        expect(subject).to_not permit(user, OpenStruct.new(poa_code: '123'))
      end
    end
  end
end
