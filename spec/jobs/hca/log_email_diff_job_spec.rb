# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::LogEmailDiffJob, type: :job do
  let!(:in_progress_form) { create(:in_progress_1010ez_form_with_email) }
  let!(:user) { create(:user, :loa3) }

  before do
    in_progress_form.update!(user_uuid: user.uuid)
    allow(User).to receive(:find).with(in_progress_form.user_uuid).and_return(user)
  end

  def self.expect_does_nothing
    it 'does nothing' do
      expect(StatsD).not_to receive(:set)
      subject
    end
  end

  def self.expect_email_tag(tag)
    it "logs that email is #{tag}" do
      expect(StatsD).to receive(:set).with(
        'api.1010ez.in_progress_form_email',
        in_progress_form.user_uuid,
        sample_rate: 1.0,
        tags: {
          email: tag
        }
      )

      subject
    end
  end

  describe '#perform' do
    subject { described_class.new.perform(in_progress_form.id) }

    context 'when form email is present' do
      context 'when email confirmation is different' do
        before do
          in_progress_form.update!(
            form_data: JSON.parse(in_progress_form.form_data).except('view:email_confirmation').to_json
          )
        end

        expect_does_nothing
      end

      context 'when va profile email is different' do
        expect_email_tag('different')
      end

      context 'when va profile is the same' do
        before do
          expect(user).to receive(:va_profile_email).and_return('Email@email.com')
        end

        expect_email_tag('same')
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
