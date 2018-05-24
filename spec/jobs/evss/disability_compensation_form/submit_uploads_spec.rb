# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:form_submission) { double(:form_submission, claim_id: 'foo') }
  let(:in_progress_form) { double(:in_progress_form, uploads: [{
    guid: 123,
    file_name: 'foo',
    enum: 5
  }]) }
  let(:client) { double(:client) }
  let(:form_attachment) { double(:form_attachment, file_data: file_body) }
  let(:file_body) { 'bar' }

  subject { described_class }

  before do
    allow(::DisabilityCompensationSubmission).
      to receive(:find_by).
      and_return(form_submission)
    allow(InProgressDisabilityCompensationForm).
      to receive(:form_for_user).
      and_return(in_progress_form)
    allow(EVSS::DocumentsService).
      to receive(:new).
      and_return(client)
  end

  it 'calls perform async for each upload' do
    expect(client).to receive(:upload)
    subject.start(user.uuid, auth_headers)
  end
end
