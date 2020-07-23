# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10203 do
  let(:instance) { FactoryBot.build(:va10203) }
  let(:user) { create(:evss_user) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10203')

  describe '#in_progress_form_id' do
    it 'returns 22-10203' do
      expect(instance.in_progress_form_id).to eq('22-10203')
    end
  end

  describe '#after_submit' do
    context 'authorized' do
      before do
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(true)
      end

      context 'sco email sent is false' do
        let(:gi_bill_status) do
          {
            remaining_entitlement: { months: 0, days: 12 },
            enrollments: [{
              begin_date: '2012-11-01T04:00:00.000+00:00',
              end_date: '2012-12-01T05:00:00.000+00:00',
              facility_code: '11902614',
              facility_name: 'Purdue University',
              participant_id: '11170323',
              training_type: 'UNDER_GRAD',
              term_id: nil,
              hour_type: nil,
              full_time_hours: 12,
              full_time_credit_hour_under_grad: nil,
              vacation_day_count: 0,
              on_campus_hours: 12.0,
              online_hours: 0.0,
              yellow_ribbon_amount: 0.0,
              status: 'Approved',
              amendments: []
            }]
          }
        end

        it 'when no remaining entitlement is present' do
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status).and_return({})

          instance.after_submit(user)
          expect(instance.parsed_form['scoEmailSent']).to eq(false)
        end

        it 'when no facility code is present' do
          bad_gi_bill_status = {
            remaining_entitlement: { months: 0, days: 12 },
            enrollments: []
          }
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
            .and_return(bad_gi_bill_status)

          instance.after_submit(user)
          expect(instance.parsed_form['scoEmailSent']).to eq(false)
        end

        # it 'when FeatureFlipper.send_email? is false' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
        #
        # it 'when more than six months of entitlement remaining' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
        #
        # it 'when institution is blank' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
        #
        # it 'when school has changed' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
        #
        # it 'when neither a primary or secondary sco with an email address is found' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
      end
    end

    context 'unauthorized' do
      before do
        unauthorized_evss_user = build(:unauthorized_evss_user, :loa3)
        expect(unauthorized_evss_user).to receive(:authorize).with(:evss, :access?).and_return(false)
                                                             .at_least(:once)
        expect(unauthorized_evss_user.authorize(:evss, :access?)).to eq(false)
      end

      it 'sco email sent is false' do
        instance.after_submit(user)
        expect(instance.parsed_form['scoEmailSent']).to eq(false)
      end
    end
  end
end
