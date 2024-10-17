# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecondaryAppealForm, type: :model do
  subject { build(:secondary_appeal_form, form_id: '4142') }

  it 'validates the presence of a guid' do
    subject.guid = nil
    expect(subject).not_to be_valid
  end

  context 'validates against the form schema' do
    before do
      expect(subject).to be_valid
      expect(JSON::Validator).to receive(:fully_validate).once.and_call_original
    end

    it 'rejects forms with missing elements' do
      bad_form = JSON.parse(subject).deep_dup.delete('something')
      subject.form = bad_form.to_json
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages.size).to eq(1)
      expect(subject.errors.full_messages).to include(/something/)
    end
  end
  
end
