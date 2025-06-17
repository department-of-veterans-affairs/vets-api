# frozen_string_literal: true

require 'rails_helper'

describe MHVPrescriptionsPolicy do
  subject { described_class }

  context "post-MHV-Account-Creation-release policy" do
    before { Flipper.enable(:mhv_medications_new_policy) }

    permissions :access? do
      context 'with a user who can create an MHV account' do
        let(:user) { build(:user, :loa3) }

        it 'grants access' do
          expect(subject).to permit(user, :rx)
        end
      end

      context 'with a user who cannot create an MHV account' do
        let(:user) { build(:user, :loa1) }

        it 'denies access' do
          expect(subject).not_to permit(user, :rx)
        end
      end
    end
  end

  context "pre-MHV-Account-Creation-release policy" do
    before { Flipper.disable(:mhv_medications_new_policy) }

    permissions :access? do
      context 'with a user who can create an MHV account' do
        let(:user) { build(:user, :loa3) }

        it 'grants access' do
          expect(subject).to permit(user, :rx)
        end
      end

      context 'with a user who cannot create an MHV account' do
        let(:user) { build(:user, :loa1) }

        it 'denies access' do
          expect(subject).not_to permit(user, :rx)
        end
      end
    end
  end
end
