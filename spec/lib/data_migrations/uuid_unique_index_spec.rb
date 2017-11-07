# frozen_string_literal: true
require 'rails_helper'

describe DataMigrations::UuidUniqueIndex, type: :model do
  let(:time) { Time.zone.now }
  2.times do |i|
    let!("in_progress_form#{i}") { create(:in_progress_form, updated_at: time - i.hours) }
  end

  it 'should migrate the records' do
    described_class.run
    expect(model_exists?(in_progress_form0)).to eq(true)
    expect(model_exists?(in_progress_form1)).to eq(false)
  end
end
