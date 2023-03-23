# frozen_string_literal: true

require 'rails_helper'

describe VANotify::FindInProgressForms do
  it 'verify form_ids are valid' do
    valid_form_ids = FormProfile::ALL_FORMS.values.flatten
    expect(valid_form_ids).to include(*described_class::RELEVANT_FORMS)
  end

  it 'verify correct form ids' do
    expect(described_class::RELEVANT_FORMS).to eq(%w[686C-674 1010ez 21-526EZ])
  end

  describe '#to_notify' do
    let(:user) { create(:user, uuid: SecureRandom.uuid) }

    it 'fetches only relevant forms by id' do
      in_progress_form_1 = create_in_progress_form_days_ago(7, user_uuid: user.uuid, form_id: '686C-674')
      in_progress_form_2 = create_in_progress_form_days_ago(7, user_uuid: user.uuid, form_id: '1010ez')
      create_in_progress_form_days_ago(7, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid, form_id: 'something')
      create_in_progress_form_days_ago(7, form_id: '1010')

      subject = described_class.new

      expect(subject.to_notify).to match_array([in_progress_form_2.id, in_progress_form_1.id])
    end

    context 'only fetches saved forms based on the correct cadence' do
      it '7 days' do
        create_in_progress_form_days_ago(6, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                            form_id: '686C-674')
        in_progress_form_1 = create_in_progress_form_days_ago(7, user_uuid: user.uuid, form_id: '686C-674')
        create_in_progress_form_days_ago(8, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                            form_id: '686C-674')

        subject = described_class.new

        expect(subject.to_notify).to eq([in_progress_form_1.id])
      end
    end
  end

  def create_in_progress_form_days_ago(count, form_id:, user_uuid: nil)
    user_uuid ||= SecureRandom.uuid
    Timecop.freeze(count.days.ago)
    in_progress_form = create(:in_progress_686c_form, user_uuid:, form_id:)
    Timecop.return
    in_progress_form
  end
end
