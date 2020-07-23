# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10203 do
  let(:instance) { build(:va10203) }
  let(:user) { create(:evss_user) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10203')

  describe '#in_progress_form_id' do
    it 'returns 22-10203' do
      expect(instance.in_progress_form_id).to eq('22-10203')
    end
  end

  def sco_email_sent_false
    instance.after_submit(user)
    expect(instance.parsed_form['scoEmailSent']).to eq(false)
  end

  describe '#after_submit' do
    context 'authorized' do
      before do
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(true)
      end

      context 'when gi_bill_status does not have remaining_entitlement' do
        before do
          gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: nil)
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(gi_bill_status)
        end

        it 'sco email sent is false' do
          sco_email_sent_false
        end
      end

      context 'when no facility code is present' do
        before do
          gi_bill_status = build(:gi_bill_status_response, enrollments: [])
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(gi_bill_status)
        end

        it 'sco email sent is false' do
          sco_email_sent_false
        end
      end

      context 'when FeatureFlipper.send_email? is false' do
        before do
          gi_bill_status = build(:gi_bill_status_response)
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(gi_bill_status)

          gids_response = build(:gids_response)
          allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
            .and_return(gids_response)

          expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
        end

        it 'sco email sent is false' do
          sco_email_sent_false
        end
      end

      context 'when more than six months of entitlement remaining' do
        before do
          remaining_entitlement = { months: 10, days: 12 }

          gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: remaining_entitlement)
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(gi_bill_status)

          gids_response = build(:gids_response)
          allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
            .and_return(gids_response)

          expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        end

        it 'sco email sent is false' do
          sco_email_sent_false
        end
      end

      context 'when institution is blank' do
        before do
          gi_bill_status = build(:gi_bill_status_response)
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(gi_bill_status)

          gids_response = build(:gids_response, :empty)
          allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
            .and_return(gids_response)

          expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        end

        it 'sco email sent is false' do
          sco_email_sent_false
        end
      end

      context 'when school has changed' do
        before do
          gi_bill_status = build(:gi_bill_status_response)
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(gi_bill_status)

          gids_response = build(:gids_response)
          allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
            .and_return(gids_response)

          expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        end

        it 'sco email sent is false' do
          form = build(:va10203, :school_changed)
          form.after_submit(user)
          expect(form.parsed_form['scoEmailSent']).to eq(false)
        end
      end

      context 'when neither a primary or secondary sco with an email address is found' do
        before do
          gi_bill_status = build(:gi_bill_status_response)
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(gi_bill_status)

          gids_response = build(:gids_response, :no_scos)
          allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
            .and_return(gids_response)

          expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        end

        it 'sco email sent is false' do
          sco_email_sent_false
        end
      end

      context 'when all conditions are met' do
        before do
          gi_bill_status = build(:gi_bill_status_response)
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(gi_bill_status)

          gids_response = build(:gids_response)
          allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
            .and_return(gids_response)

          expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
          allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now)
        end

        it 'sco email sent is true' do
          instance.after_submit(user)
          expect(instance.parsed_form['scoEmailSent']).to eq(true)
        end
      end
    end

    context 'unauthorized' do
      it 'sco email sent is false' do
        unauthorized_evss_user = build(:unauthorized_evss_user, :loa3)

        instance.after_submit(unauthorized_evss_user)
        expect(instance.parsed_form['scoEmailSent']).to eq(false)
      end
    end
  end
end
