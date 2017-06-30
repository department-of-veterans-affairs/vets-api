# frozen_string_literal: true
require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::Burial do
  subject { described_class.new }
  let(:instance) { FactoryGirl.build(:burial_claim) }

  it_should_behave_like 'saved_claim'

  xit 'can generate a pdf' do
    instance.to_pdf
  end
end
