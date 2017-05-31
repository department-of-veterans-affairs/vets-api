# frozen_string_literal: true
require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe InProgressForm, type: :model do
  describe 'form encryption' do
    it 'encrypts the form data field' do
      expect(subject).to encrypt_attr(:form_data)
    end
  end

  describe '#serialize_form_data' do
    let(:form_data) do
      { a: 1 }
    end

    it 'serializes form_data as json' do
      in_progress_form = build(:in_progress_form)
      in_progress_form.form_data = form_data
      in_progress_form.save!

      expect(in_progress_form.form_data).to eq(form_data.to_json)
    end
  end
end
