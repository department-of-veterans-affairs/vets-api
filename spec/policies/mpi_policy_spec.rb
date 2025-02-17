# frozen_string_literal: true

require 'rails_helper'

describe MPIPolicy do
  subject { described_class }

  permissions :queryable? do
    let(:user) { build(:user, :loa3, :no_mpi_profile) }

    before { stub_mpi_not_found }

    context 'with a user who has the required mvi attributes' do
      context 'where user has an icn, but not the required personal attributes' do
        it 'is queryable' do
          user.identity.attributes = {
            icn: 'some-icn',
            ssn: nil,
            first_name: nil,
            last_name: nil,
            birth_date: nil,
            gender: nil
          }

          expect(subject).to permit(user, :mvi)
        end
      end

      context 'where user has no icn, but does have a first_name, last_name, birth_date, ssn and gender' do
        it 'is queryable' do
          allow(user).to receive(:icn).and_return(nil)

          expect(subject).to permit(user, :mvi)
        end
      end
    end

    context 'with a user who does not have the required mvi attributes' do
      context 'where user has no icn' do
        before { allow(user).to receive(:icn).and_return(nil) }

        it 'is not queryable without a ssn' do
          user.identity.ssn = nil

          expect(subject).not_to permit(user, :mvi)
        end

        it 'is not queryable without a first_name' do
          user.identity.first_name = nil

          expect(subject).not_to permit(user, :mvi)
        end

        it 'is not queryable without a last_name' do
          user.identity.last_name = nil

          expect(subject).not_to permit(user, :mvi)
        end

        it 'is not queryable without a birth_date' do
          user.identity.birth_date = nil

          expect(subject).not_to permit(user, :mvi)
        end

        it 'is not queryable without a gender' do
          user.identity.gender = nil

          expect(subject).not_to permit(user, :mvi)
        end
      end
    end
  end

  permissions :access_add_person_proxy? do
    context 'with a user who is missing birls and participant id' do
      let(:user) { build(:user_with_no_ids) }

      it 'grants access' do
        expect(subject).to permit(user, :mvi)
      end
    end

    context 'with a user who is missing only participant or birls id' do
      let(:user) { build(:user, :loa3, birls_id: nil) }

      it 'grants access' do
        expect(subject).to permit(user, :mvi)
      end
    end

    context 'with a user who is missing EDIPI' do
      let(:user) { build(:unauthorized_evss_user, :loa3) }

      it 'denies access' do
        expect(subject).not_to permit(user, :mvi)
      end
    end

    context 'with a user who is missing a SSN' do
      let(:user) { build(:user, ssn: nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :mvi)
      end
    end

    context 'with a user who already has the birls and participant ids' do
      let(:user) { build(:user, :loa3) }

      it 'denies access' do
        expect(subject).not_to permit(user, :mvi)
      end
    end
  end
end
