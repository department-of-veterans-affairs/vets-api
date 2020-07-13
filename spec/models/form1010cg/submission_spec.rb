# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Submission, type: :model do
  it 'has attribute accessors for :carma_case_id, :submitted_at' do
    carma_case_id = 'A48T4sid4FGNS49CAS'
    submitted_at = DateTime.now.iso8601

    subject.carma_case_id = carma_case_id
    subject.submitted_at = submitted_at

    expect(subject.carma_case_id).to eq(carma_case_id)
    expect(subject.submitted_at).to eq(submitted_at)
    expect(subject.attachments).to eq([])
  end
end
