# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::PreneedSubmission, type: :model do
  subject { build(:preneed_submission) }

  describe 'when validating' do
    it 'has a valid factory' do
      expect(subject).to be_valid
    end

    it 'requires a tracking_number' do
      subject.tracking_number = nil
      expect(subject).not_to be_valid
    end

    it 'requires a return_description' do
      subject.return_description = nil
      expect(subject).not_to be_valid
    end
  end
end
