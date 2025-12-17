# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsVerification::SavedClaim do
  subject { described_class.new }

  let(:instance) { build(:dependents_verification_claim) }

  it 'responds to #confirmation_number' do
    expect(subject.confirmation_number).to eq(subject.guid)
  end

  it 'has necessary constants' do
    expect(described_class).to have_constant(:FORM)
  end

  it 'descends from saved_claim' do
    expect(described_class.ancestors).to include(SavedClaim)
  end

  describe '#email' do
    context 'with va_profile_email feature disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lifestage_va_profile_email).and_return(false)
      end

      it 'returns the users email' do
        expect(instance.email).to eq('maximal@example.com')
      end
    end

    context 'with va_profile_email feature enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lifestage_va_profile_email).and_return(true)
      end

      it 'returns the va_profile_email if present' do
        form_data = instance.parsed_form
        form_data['va_profile_email'] = 'va_profile@example.com'
        allow(instance).to receive(:parsed_form).and_return(form_data)
        expect(instance.email).to eq('va_profile@example.com')
      end

      it 'returns the users email if va_profile_email is not present' do
        expect(instance.email).to eq('maximal@example.com')
      end
    end
  end

  describe '#business_line' do
    it 'returns the correct business line' do
      expect(subject.business_line).to eq('OTH')
    end
  end

  describe '#veteran_first_name' do
    it 'returns the first name of the veteran from parsed_form' do
      expect(instance.veteran_first_name).to eq('Jane')
    end

    it 'returns nil if the key does not exist' do
      allow(instance).to receive(:parsed_form).and_return({})
      expect(instance.veteran_first_name).to be_nil
    end
  end

  describe '#veteran_last_name' do
    it 'returns the last name of the veteran from parsed_form' do
      expect(instance.veteran_last_name).to eq('Maximal')
    end

    it 'returns nil if the key does not exist' do
      allow(instance).to receive(:parsed_form).and_return({})
      expect(instance.veteran_last_name).to be_nil
    end
  end

  it 'inherits init callsbacks from saved_claim' do
    expect(subject.form_id).to eq(DependentsVerification::FORM_ID)
    expect(subject.guid).not_to be_nil
    expect(subject.type).to eq(DependentsVerification::SavedClaim.to_s)
  end
end
