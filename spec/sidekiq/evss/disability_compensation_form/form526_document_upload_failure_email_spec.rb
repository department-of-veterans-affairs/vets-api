# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail, type: :job do
  let!(:form526_submission) do
    create(
      :form526_submission,
      :with_uploads
    )
  end

  let(:upload_data) { [form526_submission.form[Form526Submission::FORM_526_UPLOADS].first] }
  let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg') }
  let!(:form_attachment) do
    sea = SupportingEvidenceAttachment.new(
      guid: upload_data.first['confirmationCode']
    )

    sea.set_file_data!(file)
    sea.save!
    sea
  end

  let(:notification_client) { double('Notifications::Client') }

  before do
    Sidekiq::Job.clear_all
    allow(Notifications::Client).to receive(:new).and_return(notification_client)
  end

  it 'dispatches a failure notification email with an obscured filename' do
    formatted_submit_date = form526_submission.created_at.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    obscured_filename = 'sm_***e1.jpg'

    expect(notification_client).to receive(:send_email).with(
      # Email address and first_name are from our User fixtures
      {
        email_address: 'test@email.com',
        template_id: 'form_526_document_upload_failed',
        personalisation: {
          first_name: 'BEYONCE',
          filename: obscured_filename,
          date_submitted: formatted_submit_date
        }
      }
    )

    subject.perform(form526_submission.id, form_attachment.guid)
  end
end
