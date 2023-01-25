# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::Slack::StuckRecordNotification do
  describe '#message_text' do
    let(:param) do
      {
        record_type: 'HigherLevelReview',
        id: 'this-is-a-uuid',
        status: 'pending',
        created_at: DateTime.now
      }
    end
    let(:params) { [param] }

    it 'includes the VSP environment' do
      with_settings(Settings, vsp_environment: 'staging') do
        expect(
          described_class.new(params).message_text
        ).to include('ENVIRONMENT: :construction: staging :construction')
      end
    end

    it 'lists all provided stuck records' do
      with_settings(Settings, vsp_environment: 'staging') do
        expect(
          described_class.new(params).message_text
        ).to include(
          "* #{param[:record_type]} `#{param[:id]}` (#{param[:status]}, created #{param[:created_at].iso8601})"
        )
      end
    end
  end
end
