# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe IncomeAndAssets::SavedClaim, :uploader_helpers do
  subject { described_class.new }

  let(:instance) { build(:income_and_assets_claim) }

  it_behaves_like 'saved_claim_with_confirmation_number'
end
