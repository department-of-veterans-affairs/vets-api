# frozen_string_literal: true

require 'rails_helper'

shared_examples 'supplemental document upload provider' do
  subject { described_class.new(submission) }

  let(:submission) { create(:form526_submission) }

  it { is_expected.to respond_to(:generate_upload_document) }
  it { is_expected.to respond_to(:validate_upload_document) }
  it { is_expected.to respond_to(:submit_upload_document) }
end
