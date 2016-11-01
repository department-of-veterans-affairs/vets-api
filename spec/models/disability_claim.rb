# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaim do
  context 'with valid attributes' do
    subject { described_class.new(params) }
    let(:params) { attributes_for :disability_claim }
    let(:old_updated_at) { subject.updated_at }

    it 'sets updated_at for new raw_claims' do
      subject.update_evss_data({})
      expect(subject.updated_at).to be >= old_updated_at
    end
  end
end
