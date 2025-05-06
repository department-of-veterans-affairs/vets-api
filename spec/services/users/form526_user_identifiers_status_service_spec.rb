# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Form526UserIdentifiersStatusService do
  describe '#call' do
    let(:user) { build(:user) }

    describe 'participant_id validation' do
      context 'when participant_id is missing' do
        it "returns a hash with 'participant_id' marked false" do
          allow(user).to receive(:participant_id).and_return(nil)
          expect(Users::Form526UserIdentifiersStatusService.call(user)['participant_id']).to be(false)
        end
      end

      context 'when participant_id is present' do
        it "returns a hash with 'participant_id' marked true" do
          allow(user).to receive(:participant_id).and_return('8675309')
          expect(Users::Form526UserIdentifiersStatusService.call(user)['participant_id']).to be(true)
        end
      end
    end

    describe 'birls_id validation' do
      context 'when birls_id is missing' do
        it "returns a hash with 'birls_id' marked false" do
          allow(user).to receive(:birls_id).and_return(nil)
          expect(Users::Form526UserIdentifiersStatusService.call(user)['birls_id']).to be(false)
        end
      end

      context 'when birls_id is present' do
        it 'returns a hash with birls_id marked true' do
          allow(user).to receive(:birls_id).and_return('8675309')
          expect(Users::Form526UserIdentifiersStatusService.call(user)['birls_id']).to be(true)
        end
      end
    end

    describe 'ssn validation' do
      context 'when ssn is missing' do
        it "returns a hash with 'ssn' marked false" do
          allow(user).to receive(:ssn).and_return(nil)
          expect(Users::Form526UserIdentifiersStatusService.call(user)['ssn']).to be(false)
        end
      end

      context 'when ssn is present' do
        it 'returns a hash with ssn marked true' do
          allow(user).to receive(:ssn).and_return('8675309')
          expect(Users::Form526UserIdentifiersStatusService.call(user)['ssn']).to be(true)
        end
      end
    end

    describe 'birth_date validation' do
      context 'when birth_date is missing' do
        it "returns a hash with 'birth_date' marked false" do
          allow(user).to receive(:birth_date).and_return(nil)
          expect(Users::Form526UserIdentifiersStatusService.call(user)['birth_date']).to be(false)
        end
      end

      context 'when birth_date is present' do
        it 'returns a hash with birth_date marked true' do
          allow(user).to receive(:birth_date).and_return('1985-10-26')
          expect(Users::Form526UserIdentifiersStatusService.call(user)['birth_date']).to be(true)
        end
      end
    end

    describe 'edipi validation' do
      context 'when edipi is missing' do
        it "returns a hash with 'edipi' marked false" do
          allow(user).to receive(:edipi).and_return(nil)
          expect(Users::Form526UserIdentifiersStatusService.call(user)['edipi']).to be(false)
        end
      end

      context 'when edipi is present' do
        it 'returns a hash with edipi marked true' do
          allow(user).to receive(:edipi).and_return('8675309')
          expect(Users::Form526UserIdentifiersStatusService.call(user)['edipi']).to be(true)
        end
      end
    end
  end
end
