# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::IntentToFile do
  describe 'an Intent To File has previously been submitted' do
    let(:params) do
      {
        'benefit_selection' => {
          'COMPENSATION' => true
        },
        'preparer_identification' => 'VETERAN',
        'preparer_id' => {
          'ssn' => 'fake-ssn'
        }
      }
    end

    it 'returns no confirmation number and no expiration date if no new ITF is filed' do
      user = build(:user)
      allow(user).to receive_messages(icn: '123498767V234859', participant_id: 'fake-participant-id')
      intent_to_file_service = SimpleFormsApi::IntentToFile.new(user, params)
      expiration_date = 'fake-expiration-date'
      compensation_intent = {
        'data' => {
          'attributes' => {
            'expirationDate' => expiration_date
          }
        }
      }
      allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('compensation')
                                                                                    .and_return(compensation_intent)
      allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('pension').and_return(nil)
      allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('survivor').and_return(nil)

      result = intent_to_file_service.submit

      expect(result).to eq [nil, nil]
    end
  end

  describe 'no Intent to File has previously been submitted' do
    let(:ssn) { 'fake-ssn' }
    let(:params) do
      {
        'benefit_selection' => {
          'COMPENSATION' => true
        },
        'preparer_identification' => 'VETERAN',
        'veteran_id' => {
          'ssn' => ssn
        }
      }
    end

    it 'return the expiration date of a newly-created Intent To File' do
      user = build(:user)
      intent_to_file_service = SimpleFormsApi::IntentToFile.new(user, params)
      expiration_date = 'fake-expiration-date'
      id = 'fake-id'
      compensation_intent = {
        'data' => {
          'id' => id,
          'attributes' => {
            'expirationDate' => expiration_date
          }
        }
      }
      allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('compensation')
                                                                                    .and_return(nil)
      allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('pension').and_return(nil)
      allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('survivor').and_return(nil)
      allow_any_instance_of(BenefitsClaims::Service).to receive(:create_intent_to_file).with(
        'compensation',
        ssn
      ).and_return(compensation_intent)

      result = intent_to_file_service.submit

      expect(result).to eq [id, expiration_date]
    end
  end
end
