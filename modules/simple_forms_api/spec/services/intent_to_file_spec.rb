# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::IntentToFile do
  let(:ssn) { 'fake-ssn' }
  let(:icn) { '123498767V234859' }
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

  describe '#submit' do
    let(:expiration_date) { 'fake-expiration-date' }
    let(:id) { 'fake-id' }
    let(:compensation_intent) do
      {
        'data' => {
          'id' => id,
          'attributes' => {
            'expirationDate' => expiration_date
          }
        }
      }
    end

    context 'lighthouse service is down' do
      it 'raises Exceptions::BenefitsClaimsApiDownError' do
        intent_to_file_service = SimpleFormsApi::IntentToFile.new(build(:user), params)
        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('compensation')
                                                                                      .and_return(nil)
        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('pension').and_return(nil)
        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_intent_to_file).with('survivor').and_return(nil)
        allow_any_instance_of(BenefitsClaims::Service).to receive(:create_intent_to_file).with(
          'compensation',
          ssn
        ).and_raise(Common::Exceptions::ResourceNotFound)

        expect { intent_to_file_service.submit }.to raise_error(SimpleFormsApi::Exceptions::BenefitsClaimsApiDownError)
      end
    end
  end

  describe 'an Intent To File has previously been submitted' do
    it 'returns no confirmation number and no expiration date if no new ITF is filed' do
      user = build(:user)
      allow(user).to receive_messages(icn:, participant_id: 'fake-participant-id')
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
    it 'return the expiration date of a newly-created Intent To File' do
      intent_to_file_service = SimpleFormsApi::IntentToFile.new(build(:user), params)
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
