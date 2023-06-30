# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/letters_generator/veteran_sponsor_resolver'

RSpec.describe Lighthouse::LettersGenerator::VeteranSponsorResolver do
  describe '#get_icn' do
    context 'for a dependent' do
      let(:dependent_user) { FactoryBot.build(:dependent_user_with_relationship, :loa3) }

      context 'with relationships' do
        it 'returns the ICN of the Veteran sponsor of the dependent user' do
          actual_sponsor_icn = Lighthouse::LettersGenerator::VeteranSponsorResolver.get_icn(dependent_user)
          expect(actual_sponsor_icn).to eq('9900123456V123456')
        end
      end

      context 'with no relationships' do
        before do
          allow(dependent_user).to receive(:relationships).and_return(nil)
        end

        it 'raises an error if the dependent has no Veteran relationships' do
          expect { Lighthouse::LettersGenerator::VeteranSponsorResolver.get_icn(dependent_user) }
            .to raise_error(ArgumentError)
        end
      end
    end

    context 'for a Veteran' do
      let(:veteran_user) { FactoryBot.build(:user, :loa3) }

      it 'returns the ICN of the Veteran themselves if there are no dependents' do
        allow(veteran_user).to receive(:relationships).and_return(nil)
        actual_veteran_icn = Lighthouse::LettersGenerator::VeteranSponsorResolver.get_icn(veteran_user)
        expect(actual_veteran_icn).to eq('123498767V234859')
      end
    end
  end
end
