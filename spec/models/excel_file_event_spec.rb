# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExcelFileEvent, type: :model do
  subject { described_class.new }

  it 'validates filename uniqueness' do
    create(:excel_file_event, filename: 'test_file.csv')
    duplicate = build(:excel_file_event, filename: 'test_file.csv')
    expect(duplicate.valid?).to be(false)
  end

  describe 'build_event' do
    before do
      ExcelFileEvent.delete_all
    end

    it 'returns a successful existing event' do
      successful_event = create(:excel_file_event, :successful)
      event = ExcelFileEvent.build_event(successful_event.filename)
      expect(successful_event.id).to eq(event.id)
      expect(successful_event.filename).to eq(event.filename)
    end

    it 'returns a non-successful existing event with incremented retry attempt' do
      non_successful_event = create(:excel_file_event)
      event = ExcelFileEvent.build_event(non_successful_event.filename)
      expect(non_successful_event.id).to eq(event.id)
      expect(event.retry_attempt).to eq(non_successful_event.retry_attempt + 1)
    end

    it 'returns a new event when filename pattern does not match existing events' do
      filename = "22-10282_#{Time.zone.now.strftime('%Y%m%d')}.csv"
      event = ExcelFileEvent.build_event(filename)
      expect(event.filename).to eq(filename)
      expect(event.retry_attempt).to eq(0)
    end
  end
end
