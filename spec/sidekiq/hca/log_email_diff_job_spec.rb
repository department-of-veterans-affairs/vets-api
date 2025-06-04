# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::LogEmailDiffJob, type: :job do
  let!(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }
  let!(:in_progress_form) do
    create(:in_progress_1010ez_form_with_email, user_uuid: user.uuid, user_account_id: user.user_account_uuid)
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
    allow(User).to receive(:find).with(user.uuid).and_return(user)
  end

  def self.expect_does_nothing
    it 'does nothing' do
      expect(StatsD).not_to receive(:increment)

      subject

      expect(FormEmailMatchesProfileLog).not_to receive(:find_or_create_by).with(
        user_uuid: user.uuid, in_progress_form_id: in_progress_form.id, user_account_id: user.user_account_uuid
      )
    end
  end

  def self.expect_email_tag(tag)
    it "logs that email is #{tag}" do
      expect do
        subject
      end.to trigger_statsd_increment("api.1010ez.in_progress_form_email.#{tag}")

      expect(InProgressForm.where(user_uuid: user.uuid, user_account_id: user.user_account_uuid,
                                  id: in_progress_form.id)).to exist
    end
  end

  describe '#perform' do
    subject { described_class.new.perform(in_progress_form.id, user.uuid, user.user_account_uuid) }

    context 'when the form has been deleted' do
      before do
        in_progress_form.destroy!
      end

      expect_does_nothing
    end

    context 'when form email is present' do
      context 'when va profile email is different' do
        expect_email_tag('different')
      end

      context 'when va profile is the same' do
        before do
          allow(user).to receive(:va_profile_email).and_return('Email@email.com')
        end

        expect_email_tag('same')

        context 'when FormEmailMatchesProfileLog already exists' do
          before do
            FormEmailMatchesProfileLog.create(user_uuid: user.uuid, in_progress_form_id: in_progress_form.id,
                                              user_account_id: user.user_account_uuid)
          end

          expect_does_nothing
        end

        context 'when FormEmailMatchesProfileLog find_or_create_by returns model' do
          before do
            form_email_matches_profile_log = FormEmailMatchesProfileLog.new(
              user_uuid: user.uuid,
              in_progress_form_id: in_progress_form.id,
              user_account_id: user.user_account_uuid
            )
            allow(FormEmailMatchesProfileLog).to receive(:find_or_create_by).and_return(form_email_matches_profile_log)
          end

          it 'does not increment statsd' do
            expect(StatsD).not_to receive(:increment)

            subject
          end
        end
      end

      context 'when va profile email is blank' do
        before do
          expect(user).to receive(:va_profile_email).and_return(nil)
        end

        expect_email_tag('different')
      end
    end

    context 'when form email is blank' do
      before do
        in_progress_form.update!(
          form_data: JSON.parse(in_progress_form.form_data).except('email').to_json
        )
      end

      expect_does_nothing
    end
  end
end
