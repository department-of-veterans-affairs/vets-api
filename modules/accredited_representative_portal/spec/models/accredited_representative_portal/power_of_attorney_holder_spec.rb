# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyHolder, type: :model do
    describe '.for_user' do
      subject do
        described_class.for_user(
          email: user_email,
          icn: user_icn
        )
      end

      let(:user_email) { 'email@email.com' }
      let(:user_icn) { 'icn123' }

      context 'with no associated VSO registration' do
        it { is_expected.to be_empty }
      end

      context 'with an associated VSO registration' do
        let!(:registration) do
          create(
            :user_account_accredited_individual,
            user_account_email: user_email
          )
        end

        context 'but no associated representative in turn' do
          it { is_expected.to be_empty }
        end

        context 'and an associated representative in turn' do
          let!(:representative) do
            create(
              :representative,
              user_types:,
              poa_codes:,
              representative_id:
                registration.accredited_individual_registration_number
            )
          end

          context 'but no associated organization in turn' do
            let(:user_types) { ['attorney'] }
            let(:poa_codes) { ['A1Q'] }

            it { is_expected.to be_empty }
          end

          context 'and some associated organizations in turn' do
            let(:user_types) { ['veteran_service_officer'] }
            let(:poa_codes) do
              [].tap do |memo|
                memo << create(:organization).poa
                memo << create(:organization).poa
                memo << create(:organization).poa
              end
            end

            it { is_expected.to have_attributes(size: poa_codes.size) }
          end
        end
      end
    end
  end
end
