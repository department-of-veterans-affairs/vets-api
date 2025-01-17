# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SpoolFileEvent, type: :model do
  subject { described_class.new }

  it 'validates rpo' do
    expect(described_class.new(rpo: 351).valid?).to be(true)
    expect(described_class.new(rpo: 100).valid?).to be(false)
  end

  describe 'build_event' do
    before do
      SpoolFileEvent.delete_all
    end

    it 'returns a successful existing event' do
      successful_event = create(:spool_file_event, :successful)
      event = SpoolFileEvent.build_event(successful_event.rpo, successful_event.filename)
      expect(successful_event.id).to eq(event.id)
      expect(successful_event.rpo).to eq(event.rpo)
    end

    it 'returns a non-successful existing event' do
      non_successful_event = create(:spool_file_event)
      event = SpoolFileEvent.build_event(non_successful_event.rpo, non_successful_event.filename)
      expect(non_successful_event.id).to eq(event.id)
      expect(event.retry_attempt).to eq(non_successful_event.retry_attempt + 1)
    end

    it 'returns a new event' do
      rpo = EducationForm::EducationFacility::FACILITY_IDS[:eastern]
      filename = "#{rpo}_#{Time.zone.now.strftime('%m%d%Y_%H%M%S')}_vetsgov.spl"

      event = SpoolFileEvent.build_event(rpo, filename)
      expect(event.rpo).to eq(rpo)
      expect(event.filename).to eq(filename)
    end
  end
end
