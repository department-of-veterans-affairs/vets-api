# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe SecondaryAppealForm, type: :model do
  subject { build(:secondary_appeal_form4142) }

  describe 'validations' do
    before do
      expect(subject).to be_valid
      expect(JSON::Validator).to receive(:fully_validate).at_least(:twice).and_call_original
    end

    it { is_expected.to validate_presence_of(:guid) }

    it 'errors if trying to validate without a form_id' do
      subject.form_id = nil
      expect { subject.valid? }.to raise_error(JSON::Schema::SchemaParseError)
    end

    it 'rejects forms with missing elements' do
      bad_form = JSON.parse(subject.form).deep_dup
      bad_form.delete('privacyAgreementAccepted')
      subject.form = bad_form.to_json
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages.size).to eq(1)
      expect(subject.errors.full_messages).to include(/privacyAgreementAccepted/)
    end
  end
end
