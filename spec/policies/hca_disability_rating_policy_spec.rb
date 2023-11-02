# frozen_string_literal: true

require 'rails_helper'

describe HCADisabilityRatingPolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who is loa3 verified' do
      let(:user) { build(:user, :loa3, icn: '12345678654332534') }

      it 'grants access' do
        expect(subject).to permit(user, :hca_disability_rating)
      end
    end

    context 'with a user who is not LOA3 verified' do
      let(:user) { build(:user, :loa1, icn: '45678654356789876') }

      it 'denies access' do
        expect(subject).not_to permit(user, :hca_disability_rating)
      end
    end
  end
end
