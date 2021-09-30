# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::V0::FillMobileUserTableJob, type: :job do
  after { Mobile::V0::Users.delete_by(icn: '1234567') }

  context 'when table add succeeds' do
    it 'logs the success with user info' do
      allow(Rails.logger).to receive(:info)
      subject.perform('1234567')
      expect(Rails.logger).to have_received(:info).with(
        'Mobile user table add succeeded for user with icn ',
        { icn: '1234567' }
      )
    end
  end

  context 'when table add fails' do
    it 'logs the failure with user info' do
      allow(Rails.logger).to receive(:error)
      expect { subject.perform(nil) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Rails.logger).to have_received(:error).with(
        'Mobile user table add failed for user with icn ',
        { icn: nil }
      )
    end
  end
end
