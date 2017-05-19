require 'rails_helper'

RSpec.describe MhvAccount, type: :model do
  it 'must have a user_uuid when initialized' do
    expect { described_class.new }
      .to raise_error(StandardError, 'You must use find_or_initialize_by(user_uuid: #)')
  end

  describe 'event' do
    let(:user) { create(:loa3_user) }

    context 'check_eligibility' do
      context 'with terms accepted' do
        let(:terms) { create(:terms_and_conditions, latest: true, name: 'mhv_account_terms' ) }
        before(:each) { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid) }

        it 'is ineligible if not a va patient' do
          allow_any_instance_of(User).to receive(:icn).and_return(nil)
          subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('ineligible')
        end

        it 'is able to transition back to upgraded' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance', upgraded_at: Time.current)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('upgraded')
        end

        it 'is able to transition back to registered' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance', registered_at: Time.current)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('registered')
        end

        it 'it falls back to unknown' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('unknown')
        end
      end

      context 'with terms not accepted' do
        it 'is ineligible if not a va patient' do
          allow_any_instance_of(User).to receive(:icn).and_return(nil)
          subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('ineligible')
        end

        it 'transitions to needs_terms_acceptance' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'upgraded', upgraded_at: Time.current)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
        end

        it 'is able to transition back to registered' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'registered', registered_at: Time.current)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
        end

        it 'it falls back to unknown' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'unknown')
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
        end
      end
    end
  end
end
