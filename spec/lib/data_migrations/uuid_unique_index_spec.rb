# frozen_string_literal: true
require 'rails_helper'

describe DataMigrations::UuidUniqueIndex, type: :model do
  2.times do |i|
    let!("in_progress_form#{i}") { create(:in_progress_form) }
  end

  it 'should migrate the records' do
    described_class.run
    expect(model_exists?(in_progress_form0)).to eq(false)
    expect(model_exists?(in_progress_form1)).to eq(true)
  end
end
