# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PreneedsEmbeddedObjectValidator do
  let(:subject) { build :application_input }

  it 'validates any preneeds object embedded in another preneeds object' do
    expect(subject).to be_valid
  end

  it 'validates the fields of an embedded object' do
    subject.veteran.service_name.last_name = nil
    expect(subject).not_to be_valid
    expect(subject.errors.full_messages).to include("Veteran Service name Last name can't be blank")
  end

  it 'validates a field containing an array' do
    subject.veteran.service_records.first.branch_of_service = 'A'
    expect(subject).not_to be_valid
    expect(subject.errors.full_messages).to include(
      'Veteran Service records Branch of service is the wrong length (should be 2 characters)'
    )
  end

  it 'handles multiple embedded objects' do
    subject.veteran.service_name.last_name = nil
    subject.veteran.service_records.first.branch_of_service = 'A'

    expect(subject).not_to be_valid
    expect(subject.errors.full_messages).to include(
      "Veteran Service name Last name can't be blank, "\
      'Service records Branch of service is the wrong length (should be 2 characters)'
    )
  end
end
