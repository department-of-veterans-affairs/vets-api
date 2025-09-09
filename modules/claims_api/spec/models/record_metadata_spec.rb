# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::RecordMetadata, type: :model do
  describe 'encrypted attributes' do
    it 'are encrypted' do
      expect(subject).to encrypt_attr(:metadata)
    end
  end

  describe 'required attributes' do
    it 'validates presence of required attributes' do
      record = ClaimsApi::RecordMetadata.new
      expect(record).not_to be_valid
      expect(record.errors[:metadata]).to include("can't be blank")
      expect(record.errors[:record_type]).to include("can't be blank")
      expect(record.errors[:record_id]).to include("can't be blank")
    end
  end
end
