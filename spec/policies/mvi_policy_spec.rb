# frozen_string_literal: true

require 'rails_helper'

describe MviPolicy do
  subject { described_class }

  permissions :queryable? do
    let(:user) { build(:user, :loa3) }

    context 'with a user who has the required mvi attributes' do
      context 'where user has an icn, but not the required personal attributes' do
        it 'is queryable' do
          user.identity.attributes = {
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

          expect(subject).to_not permit(user, :mvi)
        end

        it 'is not queryable without a first_name' do
          user.identity.first_name = nil

          expect(subject).to_not permit(user, :mvi)
        end

        it 'is not queryable without a last_name' do
          user.identity.last_name = nil

          expect(subject).to_not permit(user, :mvi)
        end

        it 'is not queryable without a birth_date' do
          user.identity.birth_date = nil

          expect(subject).to_not permit(user, :mvi)
        end

        it 'is not queryable without a gender' do
          user.identity.gender = nil

          expect(subject).to_not permit(user, :mvi)
        end
      end
    end
  end
end
