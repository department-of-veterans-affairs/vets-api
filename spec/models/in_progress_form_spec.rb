# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InProgressForm, type: :model do
  let(:in_progress_form) { build(:in_progress_form) }

  describe '#log_hca_email_diff' do
    context 'with a 1010ez in progress form' do
      it 'runs the hca email diff job' do
        expect do
          create(:in_progress_1010ez_form)
        end.to change(HCA::LogEmailDiffJob.jobs, :size).by(1)
      end
    end

    context 'with a non-1010ez in progress form' do
      it 'doesnt run hca email diff job' do
        create(:in_progress_form)
        expect(HCA::LogEmailDiffJob.jobs.size).to eq(0)
      end
    end
  end

  describe 'form encryption' do
    it 'encrypts the form data field' do
      expect(subject).to encrypt_attr(:form_data)
    end
  end

  describe 'validations' do
    it 'validates presence of form_data' do
      expect_attr_valid(in_progress_form, :form_data)
      in_progress_form.form_data = nil
      expect_attr_invalid(in_progress_form, :form_data, "can't be blank")
    end
  end

  describe '#metadata' do
    it 'adds the form expiration time and id', run_at: '2017-06-01' do
      in_progress_form.save
      expect(in_progress_form.metadata['expiresAt']).to eq(1_501_459_200)
      expect(in_progress_form.metadata['inProgressFormId']).to be_an(Integer)
    end

    context 'skips the expiration_date callback wihen skip_exipry_update is true' do
      it 'adds the form expiration time and id', run_at: '2017-06-01' do
        in_progress_form.skip_exipry_update = true
        in_progress_form.save
        expect(in_progress_form.metadata['expires_at']).not_to eq(1_501_459_200)
      end
    end

    context 'when the form is 21-526EZ' do
      before { in_progress_form.form_id = '21-526EZ' }

      it 'adds a later form expiration time and id', run_at: '2017-06-01' do
        in_progress_form.save
        expect(in_progress_form.metadata['expiresAt']).to eq(1_527_811_200)
        expect(in_progress_form.metadata['inProgressFormId']).to be_an(Integer)
      end

      it 'adds a later form expiration time when a leap year', run_at: '2020-06-01' do
        in_progress_form.save
        expect(in_progress_form.metadata['expiresAt']).to eq(1_622_505_600)
      end
    end
  end

  describe '#serialize_form_data' do
    let(:form_data) do
      { a: 1 }
    end

    it 'serializes form_data as json' do
      in_progress_form.form_data = form_data
      in_progress_form.save!

      expect(in_progress_form.form_data).to eq(form_data.to_json)
    end
  end

  describe 'scopes' do
    let!(:first_record) do
      create(:in_progress_form, metadata: { submission: { hasAttemptedSubmit: true,
                                                          errors: 'foo',
                                                          errorMessage: 'bar' } })
    end
    let!(:second_record) { create(:in_progress_form, metadata: { submission: { hasAttemptedSubmit: false } }) }
    let!(:third_record) do
      create(:in_progress_form, form_id: '5655', metadata: { submission: { hasAttemptedSubmit: true, status: false } })
    end

    it 'includes records within scope' do
      expect(described_class.has_attempted_submit).to include(first_record)
      expect(described_class.has_errors).to include(first_record)
      expect(described_class.has_error_message).to include(first_record)
      expect(described_class.has_no_errors).to include(second_record)
      expect(described_class.unsubmitted_fsr).to include(third_record)
    end
  end

  describe '#expires_after' do
    context 'with in_progress_form_custom_expiration Flipper disabled' do
      context 'when 21-526EZ' do
        before do
          in_progress_form.form_id = '21-526EZ'
        end

        it 'is an ActiveSupport::Duration' do
          Flipper.disable(:in_progress_form_custom_expiration)

          expect(in_progress_form.expires_after).to be_a(ActiveSupport::Duration)
        end

        it 'value is 1 year' do
          Flipper.disable(:in_progress_form_custom_expiration)

          expect(in_progress_form.expires_after).to eq(1.year)
        end
      end

      context 'when unrecognized form' do
        before do
          in_progress_form.form_id = 'abcd-1234'
        end

        it 'is an ActiveSupport::Duration' do
          Flipper.disable(:in_progress_form_custom_expiration)

          expect(in_progress_form.expires_after).to be_a(ActiveSupport::Duration)
        end

        it 'value is 60 days' do
          Flipper.disable(:in_progress_form_custom_expiration)

          expect(in_progress_form.expires_after).to eq(60.days)
        end
      end
    end

    context 'with in_progress_form_custom_expiration Flipper enabled' do
      before do
        in_progress_form.form_id = 'HC-QSTNR_abc123'
        in_progress_form.form_data = { days_till_expires: '90' }.to_json
      end

      it 'expires in 90 days' do
        Flipper.enable(:in_progress_form_custom_expiration)

        expect(in_progress_form.expires_after).to eq(90.days)
      end
    end
  end

  describe '.form_for_user' do
    subject { InProgressForm.form_for_user(form_id, user) }

    let(:form_id) { in_progress_form.form_id }
    let(:user) { create(:user) }
    let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }

    context 'and in progress form exists associated with user uuid' do
      let!(:in_progress_form_user_uuid) { create(:in_progress_form, user_uuid: user.uuid) }

      it 'returns InProgressForms for user with given form id' do
        expect(subject).to eq(in_progress_form_user_uuid)
      end
    end

    context 'and in progress form does not exist associated with user uuid' do
      context 'and in progress form exists associated with user account on user' do
        let!(:in_progress_form_user_account) { create(:in_progress_form, user_account: user.user_account) }

        it 'returns InProgressForms for user with given form id' do
          expect(subject).to eq(in_progress_form_user_account)
        end
      end
    end
  end

  describe '.for_user' do
    subject { InProgressForm.for_user(user) }

    let(:user) { create(:user) }
    let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
    let!(:in_progress_form_user_uuid) { create(:in_progress_form, user_uuid: user.uuid) }
    let!(:in_progress_form_user_account) { create(:in_progress_form, user_account: user.user_account) }
    let(:expected_in_progress_forms_id) { [in_progress_form_user_uuid.id, in_progress_form_user_account.id] }

    it 'returns in progress forms associated with user uuid and user account' do
      expect(subject.map(&:id)).to match_array(expected_in_progress_forms_id)
    end
  end
end
