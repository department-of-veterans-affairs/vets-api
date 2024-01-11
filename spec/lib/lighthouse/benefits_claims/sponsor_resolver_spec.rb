# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/veteran_sponsor_resolver'

RSpec.describe BenefitsClaims::SponsorResolver do
  describe '#get_icn' do
    context 'for a dependent' do
      let(:dependent_user) { FactoryBot.build(:dependent_user_with_relationship, :loa3) }

      context 'with relationships' do
        it 'returns the ICN of the Veteran sponsor of the dependent user' do
          actual_sponsor_icn = BenefitsClaims::SponsorResolver.sponsor_icn(dependent_user)
          expect(actual_sponsor_icn).to eq('9900123456V123456')
        end
      end

      context 'with no relationships' do
        before do
          allow(dependent_user).to receive(:relationships).and_return(nil)
        end

        it 'raises an error if the dependent has no Veteran relationships' do
          expect { BenefitsClaims::SponsorResolver.sponsor_icn(dependent_user) }
            .to raise_error(NoMethodError)
        end
      end
    end

    context 'for a Veteran' do
      let(:veteran_user) { FactoryBot.build(:user, :loa3) }

      it 'returns nil if the logged in user is not a dependent' do
        allow(veteran_user).to receive(:relationships).and_return(nil)
        sponsor_icn = BenefitsClaims::SponsorResolver.sponsor_icn(veteran_user)
        expect(sponsor_icn).to eq(nil)
      end
    end
  end
end
