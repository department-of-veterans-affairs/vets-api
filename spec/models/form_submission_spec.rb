# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormSubmission, type: :model do
  describe 'associations' do
    it { should belong_to(:in_progress_form).optional }
    it { should belong_to(:saved_claim).optional }
    it { should belong_to(:user_account).optional }
  end

  describe 'validations' do
    # TODO: update this when we have real values e.g.
    #   it { should define_enum_for(:form_type).with_values(:form526, :form686) }
    it { should define_enum_for(:form_type).with_values(described_class.form_types.keys) }
    it { should validate_presence_of(:form_type) }
    it { should validate_presence_of(:benefits_intake_uuid) }
  end

  describe 'state machine' do
    # N/A
  end

  describe 'methods' do
    context 'class' do
      # N/A
    end

    context 'instance' do
      # N/A
    end
  end
end
