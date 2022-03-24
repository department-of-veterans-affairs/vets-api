# frozen_string_literal: true

require 'rails_helper'

describe VANotify::FindInProgressForms do
  it 'verify form_ids are valid' do
    valid_form_ids = FormProfile::ALL_FORMS.values
    expect(valid_form_ids).to include(described_class::RELEVANT_FORMS)
  end

  it 'verify correct form ids' do
    expect(described_class::RELEVANT_FORMS).to eq(%w[686C-674])
  end

  describe '#to_notify' do
    let(:user) { create(:user, uuid: SecureRandom.uuid) }

    it 'fetches only relevant forms by id' do
      in_progress_form_1 = create_in_progress_form_days_ago(14, user_uuid: user.uuid, form_id: '686C-674')
      create_in_progress_form_days_ago(14, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid, form_id: 'something')
      create_in_progress_form_days_ago(14, form_id: '1010')

      subject = described_class.new

      user_uuid = user.uuid.delete('-')
      expect(subject.to_notify).to eq({ user_uuid => [in_progress_form_1] })
    end

    context 'only fetches saved forms based on the correct cadence' do
      it '14 days' do
        create_in_progress_form_days_ago(13, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                             form_id: '686C-674')
        in_progress_form_1 = create_in_progress_form_days_ago(14, user_uuid: user.uuid, form_id: '686C-674')
        create_in_progress_form_days_ago(15, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                             form_id: '686C-674')

        subject = described_class.new

        user_uuid = user.uuid.delete('-')
        expect(subject.to_notify).to eq({ user_uuid => [in_progress_form_1] })
      end

      it '28 days' do
        create_in_progress_form_days_ago(27, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                             form_id: '686C-674')
        in_progress_form_1 = create_in_progress_form_days_ago(28, user_uuid: user.uuid, form_id: '686C-674')
        create_in_progress_form_days_ago(29, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                             form_id: '686C-674')

        subject = described_class.new

        user_uuid = user.uuid.delete('-')
        expect(subject.to_notify).to eq({ user_uuid => [in_progress_form_1] })
      end

      it '42 days' do
        create_in_progress_form_days_ago(41, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                             form_id: '686C-674')
        in_progress_form_1 = create_in_progress_form_days_ago(42, user_uuid: user.uuid, form_id: '686C-674')
        create_in_progress_form_days_ago(43, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                             form_id: '686C-674')

        subject = described_class.new

        user_uuid = user.uuid.delete('-')
        expect(subject.to_notify).to eq({ user_uuid => [in_progress_form_1] })
      end

      it '56 days' do
        create_in_progress_form_days_ago(55, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                             form_id: '686C-674')
        in_progress_form_1 = create_in_progress_form_days_ago(56, user_uuid: user.uuid, form_id: '686C-674')
        create_in_progress_form_days_ago(57, user_uuid: create(:user, uuid: SecureRandom.uuid).uuid,
                                             form_id: '686C-674')

        subject = described_class.new

        user_uuid = user.uuid.delete('-')
        expect(subject.to_notify).to eq({ user_uuid => [in_progress_form_1] })
      end
    end
  end

  def create_in_progress_form_days_ago(count, form_id:, user_uuid: nil)
    user_uuid ||= SecureRandom.uuid
    Timecop.freeze(count.days.ago)
    in_progress_form = create(:in_progress_686c_form, user_uuid: user_uuid, form_id: form_id)
    Timecop.return
    in_progress_form
  end
end
