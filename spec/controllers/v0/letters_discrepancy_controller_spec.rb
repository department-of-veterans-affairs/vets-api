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
      it 'when Lighthouse returns more letters than EVSS' do
        VCR.use_cassette('lighthouse/letters_generator/letters_discrepancy_same') do
          VCR.use_cassette('evss/letters/letters_discrepancy_less_than_lh') do
            get(:index)

            # expect(Rails.logger).to have_received(:info).with('Caseflow Request',
            #   'va_user' => 'adhoc.test.user',
            #   'lookup_identifier' => hash)

            lh_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                            service_verification civil_service benefit_summary benefit_verification]
            evss_letters = %w[commissary proof_of_service medicare_partd minimum_essential_coverage
                              service_verification civil_service benefit_summary]

            expect(Rails.logger).to have_received(:info).with('Letters Generator Discrepancies',
                                                                  { message_type: 'lh.letters_generator.letters_discrepancy',
                                                                    lh_letter_diff: 1,
                                                                    evss_letter_diff: 0,
                                                                    lh_letters: lh_letters.join(', '),
                                                                    evss_letters: evss_letters.join(', ') })
          end
        end
      end
    end
  end
end
