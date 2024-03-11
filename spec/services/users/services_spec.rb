# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Services do
  describe '#authorizations' do
    subject { Users::Services.new(user).authorizations }

    let(:user) { build :user, :loa3 }

    it 'returns an array of services authorized to the initialized user', :aggregate_failures do
      expect(subject.class).to eq Array
      expect(subject).to match_array(
        %w[
          facilities
          hca
          edu-benefits
          evss-claims
          lighthouse
          form526
          user-profile
          appeals-status
          form-save-in-progress
          form-prefill
          identity-proofed
          vet360
        ]
      )
    end

    context 'with an loa1 user' do
      let(:user) { build :user }

      it 'returns only the services that are authorized to this loa1 user' do
        expect(subject).to match_array(
          %w[
            facilities
            hca
            edu-benefits
            user-profile
            form-save-in-progress
            form-prefill
          ]
        )
      end
    end

    context 'with an MHV Premium user' do
      let(:user) { build(:user, :mhv) }

      it 'returns an array including the MHV services' do
        %w[health-records medical-records messaging rx].each do |service|
          expect(subject).to include(service)
        end
      end
    end
  end
end
