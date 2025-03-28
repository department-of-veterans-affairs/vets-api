# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::LettersDiscrepancyController, type: :controller do
  # These users are from Lighthouse API sandbox
  # https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts/letter_generator_test_accounts.md
  let(:user) { build(:user, :loa3, icn: '1012845630V900607') }

  before do
    token = 'abcdefghijklmnop'

    allow_any_instance_of(Lighthouse::LettersGenerator::Configuration).to receive(:get_access_token).and_return(token)
  end

  describe '#index' do
    before do
      sign_in_as(user)
      allow(Rails.logger).to receive(:info)
    end

    it 'does not log anything if both services return the same letters' do
      VCR.use_cassette('lighthouse/letters_generator/letters_discrepancy_same') do
        VCR.use_cassette('evss/letters/letters_discrepancy_same') do
          get(:index)
          expect(Rails.logger).not_to have_received(:info).with('Letters Generator Discrepancies')
        end
      end
    end

    context 'does log the differences between the services' do
      context 'when :letters_hide_service_verification_letter is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:letters_hide_service_verification_letter).and_return(true)
        end

        it 'when Lighthouse returns more letters than EVSS' do
          VCR.use_cassette('lighthouse/letters_generator/letters_discrepancy_same') do
            VCR.use_cassette('evss/letters/letters_discrepancy_less_than_lh') do
              get(:index)

              lh_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                              civil_service benefit_summary benefit_verification]
              evss_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                                civil_service benefit_summary]

              expect(Rails.logger)
                .to have_received(:info)
                .with('Letters Generator Discrepancies',
                      { message_type: 'lh.letters_generator.letters_discrepancy',
                        lh_letter_diff: 1,
                        evss_letter_diff: 0,
                        lh_letters: lh_letters.sort.join(', '),
                        evss_letters: evss_letters.sort.join(', ') })
            end
          end
        end

        it 'when EVSS returns more letters than Lighthouse' do
          VCR.use_cassette('lighthouse/letters_generator/letters_discrepancy_less_than_evss') do
            VCR.use_cassette('evss/letters/letters_discrepancy_same') do
              get(:index)

              lh_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                              civil_service benefit_summary]
              evss_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                                civil_service benefit_summary benefit_verification]

              expect(Rails.logger)
                .to have_received(:info)
                .with('Letters Generator Discrepancies',
                      { message_type: 'lh.letters_generator.letters_discrepancy',
                        lh_letter_diff: 0,
                        evss_letter_diff: 1,
                        lh_letters: lh_letters.sort.join(', '),
                        evss_letters: evss_letters.sort.join(', ') })
            end
          end
        end

        it 'when EVSS and Lighthouse return the same amount of letters, but different types' do
          VCR.use_cassette('lighthouse/letters_generator/letters_discrepancy_same_length_diff_types') do
            VCR.use_cassette('evss/letters/letters_discrepancy_same_length_diff_types') do
              get(:index)

              lh_letters = %w[commissary proof_of_service benefit_summary]
              evss_letters = %w[commissary proof_of_service medicare_partd]

              expect(Rails.logger)
                .to have_received(:info)
                .with('Letters Generator Discrepancies',
                      { message_type: 'lh.letters_generator.letters_discrepancy',
                        lh_letter_diff: 1,
                        evss_letter_diff: 1,
                        lh_letters: lh_letters.sort.join(', '),
                        evss_letters: evss_letters.sort.join(', ') })
            end
          end
        end
      end

      context 'when :letters_hide_service_verification_letter is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:letters_hide_service_verification_letter).and_return(false)
        end

        it 'when Lighthouse returns more letters than EVSS' do
          VCR.use_cassette('lighthouse/letters_generator/letters_discrepancy_same') do
            VCR.use_cassette('evss/letters/letters_discrepancy_less_than_lh') do
              get(:index)

              lh_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                              service_verification civil_service benefit_summary benefit_verification]
              evss_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                                service_verification civil_service benefit_summary]

              expect(Rails.logger)
                .to have_received(:info)
                .with('Letters Generator Discrepancies',
                      { message_type: 'lh.letters_generator.letters_discrepancy',
                        lh_letter_diff: 1,
                        evss_letter_diff: 0,
                        lh_letters: lh_letters.sort.join(', '),
                        evss_letters: evss_letters.sort.join(', ') })
            end
          end
        end

        it 'when EVSS returns more letters than Lighthouse' do
          VCR.use_cassette('lighthouse/letters_generator/letters_discrepancy_less_than_evss') do
            VCR.use_cassette('evss/letters/letters_discrepancy_same') do
              get(:index)

              lh_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                              service_verification civil_service benefit_summary]
              evss_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                                service_verification civil_service benefit_summary benefit_verification]

              expect(Rails.logger)
                .to have_received(:info)
                .with('Letters Generator Discrepancies',
                      { message_type: 'lh.letters_generator.letters_discrepancy',
                        lh_letter_diff: 0,
                        evss_letter_diff: 1,
                        lh_letters: lh_letters.sort.join(', '),
                        evss_letters: evss_letters.sort.join(', ') })
            end
          end
        end

        it 'when EVSS and Lighthouse return the same amount of letters, but different types' do
          VCR.use_cassette('lighthouse/letters_generator/letters_discrepancy_same_length_diff_types') do
            VCR.use_cassette('evss/letters/letters_discrepancy_same_length_diff_types') do
              get(:index)

              lh_letters = %w[commissary proof_of_service benefit_summary]
              evss_letters = %w[commissary proof_of_service medicare_partd]

              expect(Rails.logger)
                .to have_received(:info)
                .with('Letters Generator Discrepancies',
                      { message_type: 'lh.letters_generator.letters_discrepancy',
                        lh_letter_diff: 1,
                        evss_letter_diff: 1,
                        lh_letters: lh_letters.sort.join(', '),
                        evss_letters: evss_letters.sort.join(', ') })
            end
          end
        end
      end
    end
  end
end
