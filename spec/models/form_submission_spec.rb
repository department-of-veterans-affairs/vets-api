# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormSubmission, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:saved_claim).optional }
    it { is_expected.to belong_to(:user_account).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:form_type) }
  end
end
