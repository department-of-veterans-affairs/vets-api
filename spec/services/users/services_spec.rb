# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Services do
  describe '#authorizations' do
    let(:user) { build :user, :loa3 }

    subject { Users::Services.new(user).authorizations }

    it 'returns an array of services authorized to the initialized user', :aggregate_failures do
      expect(subject.class).to eq Array
      expect(subject).to contain_exactly(
        'facilities',
        'hca',
        'edu-benefits',
        'evss-claims',
        'user-profile',
        'appeals-status',
        'form-save-in-progress',
        'form-prefill',
        'identity-proofed',
        'vet360'
      )
    end

    context 'with an loa1 user' do
      let(:user) { build :user }

      it 'returns only the services that are authorized to this loa1 user' do
        expect(subject).to contain_exactly(
          'facilities',
          'hca',
          'edu-benefits',
          'user-profile',
          'form-save-in-progress',
          'form-prefill',
        )
      end
    end
  end
end
