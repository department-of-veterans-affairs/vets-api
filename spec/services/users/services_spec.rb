# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Services do
  describe '#authorizations' do
    let(:user) { build :user, :loa3 }
    let(:beta_feature_preferences) { 'preferences' }
    let(:beta_feature_admin) { 'admin' }

    before do
      create :beta_registration, user_uuid: user.uuid, feature: beta_feature_preferences
      create :beta_registration, user_uuid: user.uuid, feature: beta_feature_admin
    end

    subject { Users::Services.new(user).authorizations }

    it 'returns an array of services authorized to the initialized user', :aggregate_failures do
      expect(subject.class).to eq Array
      expect(subject).to match_array(
        [
          'facilities',
          'hca',
          'edu-benefits',
          'evss-claims',
          'form526',
          'user-profile',
          'appeals-status',
          'form-save-in-progress',
          'form-prefill',
          'identity-proofed',
          'vet360',
          beta_feature_preferences,
          beta_feature_admin
        ]
      )
    end

    context 'with an loa1 user' do
      let(:user) { build :user }

      it 'returns only the services that are authorized to this loa1 user' do
        expect(subject).to match_array(
          [
            'facilities',
            'hca',
            'edu-benefits',
            'user-profile',
            'form-save-in-progress',
            'form-prefill',
            beta_feature_preferences,
            beta_feature_admin
          ]
        )
      end
    end
  end
end
