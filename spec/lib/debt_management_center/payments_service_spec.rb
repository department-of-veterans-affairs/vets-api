# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/payments_service'

describe DebtManagementCenter::PaymentsService do
  let(:user) { build(:user, :loa3) }
  let(:bgs_people_service_instance) { double('BGS person service instance') }
  let(:bgs_payment_service_instance) { double('BGS payment service instance') }
  let(:bgs_person) { BGS::People::Response.new(bgs_person_response) }
  let(:bgs_person_response) { { ptcpnt_id: '600061742', file_nbr: '796043735', ssn_nbr: '796043735' } }
  let(:bgs_payments) do
    now = DateTime.now

    {
      payments: {
        payment: [
          # rubocop:disable Layout/SpaceBeforeComma
          { payment_date: now              , payment_type: 'Compensation & Pension - Retroactive'    },
          { payment_date: nil              , payment_type: 'Compensation & Pension - Recurring'      },
          { payment_date: now - 2.months   , payment_type: 'Compensation & Pension - Retroactive'    },
          { payment_date: now - 0.months   , payment_type: 'Post-9/11 GI Bill'                       },
          { payment_date: nil              , payment_type: 'Post-9/11 GI Bill'                       },
          { payment_date: now - 2.months   , payment_type: 'Compensation & Pension - Recurring'      },
          { payment_date: now - 2.months   , payment_type: 'Post-9/11 GI Bill'                       },
          { payment_date: now - 3.months   , payment_type: 'Compensation & Pension - Recurring'      },
          { payment_date: now - 1.month    , payment_type: 'Post-9/11 GI Bill'                       },
          { payment_date: now - 1.month    , payment_type: 'Compensation & Pension - Recurring'      }
          # rubocop:enable Layout/SpaceBeforeComma
        ]
      }
    }
  end

  def subject
    expect(BGS::People::Service).to receive(:new).with(user).and_return(bgs_people_service_instance)
    expect(bgs_people_service_instance).to receive(:find_person_by_participant_id).and_return(bgs_person)
    expect(BGS::PaymentService).to receive(:new).with(user).and_return(bgs_payment_service_instance)
    expect(bgs_payment_service_instance).to receive(:payment_history).with(bgs_person).and_return(bgs_payments)

    described_class.new(user)
  end

  it 'includes SentryLogging' do
    expect(described_class.ancestors).to include(SentryLogging)
  end

  describe '::new' do
    it 'requires a user' do
      expect { described_class.new }.to raise_error(ArgumentError) do |e|
        expect(e.message).to eq('wrong number of arguments (given 0, expected 1)')
      end
    end

    describe 'fetching person' do
      before do
        expect(BGS::People::Service).to receive(:new).with(user).and_return(bgs_people_service_instance)
      end

      context 'when person search raises an error' do
        let(:error) { double('error') }

        before do
          expect(bgs_people_service_instance).to receive(:find_person_by_participant_id).and_raise(error)
        end

        it 'sets @person to empty hash' do
          expect(described_class.new(user).instance_variable_get(:@person)).to eq({})
        end
      end

      context 'when person does not exists in BGS' do
        before do
          expect(bgs_people_service_instance).to receive(:find_person_by_participant_id).and_return({})
        end

        it 'sets @person to empty hash' do
          expect(described_class.new(user).instance_variable_get(:@person)).to eq({})
        end
      end

      context 'when person is found in BGS' do
        before do
          expect(bgs_people_service_instance).to receive(:find_person_by_participant_id).and_return(bgs_person)
        end

        it 'sets @person to the response' do
          expect(described_class.new(user).instance_variable_get(:@person)).to eq(bgs_person)
        end
      end
    end

    describe 'fetching payments' do
      before do
        expect(BGS::People::Service).to receive(:new).with(user).and_return(bgs_people_service_instance)
        expect(bgs_people_service_instance).to receive(:find_person_by_participant_id).and_return(bgs_person)

        expect(BGS::PaymentService).to receive(:new).with(user).and_return(bgs_payment_service_instance)
      end

      context 'when payment history raises an error' do
        before do
          expect(bgs_payment_service_instance).to receive(:payment_history).with(bgs_person).and_raise('error')
        end

        it 'sets @payments to empty array' do
          expect(described_class.new(user).instance_variable_get(:@payments)).to eq([])
        end
      end

      context 'when payment history is nil' do
        before do
          expect(bgs_payment_service_instance).to receive(:payment_history).with(bgs_person).and_return(nil)
        end

        it 'sets @payments to empty array' do
          expect(described_class.new(user).instance_variable_get(:@payments)).to eq([])
        end
      end

      context 'when payment history is empty' do
        before do
          expect(bgs_payment_service_instance).to receive(:payment_history).with(bgs_person).and_return({})
        end

        it 'sets @payments to empty array' do
          expect(described_class.new(user).instance_variable_get(:@payments)).to eq([])
        end
      end

      context 'when payment history is present' do
        before do
          expect(bgs_payment_service_instance).to receive(:payment_history).with(bgs_person).and_return(bgs_payments)
        end

        it 'sets @payments to the nested result' do
          expect(described_class.new(user).instance_variable_get(:@payments)).to eq(bgs_payments[:payments][:payment])
        end
      end
    end
  end

  describe '#compensation_and_pension' do
    it 'returns @payments filtered by :payment_type and sorted by [:payment_date, ASC]' do
      result = subject.compensation_and_pension

      expect(result.size).to eq(3)

      expect(result[0]).to be(bgs_payments[:payments][:payment][7])
      expect(result[1]).to be(bgs_payments[:payments][:payment][5])
      expect(result[2]).to be(bgs_payments[:payments][:payment][9])
    end

    context 'when @payments is empty' do
      before { bgs_payments[:payments][:payment] = [] }

      it 'returns nil' do
        expect(subject.compensation_and_pension).to be_nil
      end
    end

    context 'when @payments doen\'t contain matching items' do
      before do
        bgs_payments[:payments][:payment].delete_if do |payment|
          payment[:payment_type] == 'Compensation & Pension - Recurring' && payment[:payment_date].present?
        end
      end

      it 'returns nil' do
        expect(subject.compensation_and_pension).to be_nil
      end
    end
  end

  describe '#education' do
    it 'returns @payments filtered by :payment_type and sorted by [:payment_date, ASC]' do
      result = subject.education

      expect(result.size).to eq(3)

      expect(result[0]).to be(bgs_payments[:payments][:payment][6])
      expect(result[1]).to be(bgs_payments[:payments][:payment][8])
      expect(result[2]).to be(bgs_payments[:payments][:payment][3])
    end

    context 'when @payments is empty' do
      before { bgs_payments[:payments][:payment] = [] }

      it 'returns nil' do
        expect(subject.education).to be_nil
      end
    end

    context 'when @payments doen\'t contain matching items' do
      before do
        bgs_payments[:payments][:payment].delete_if do |payment|
          payment[:payment_type] == 'Post-9/11 GI Bill' && payment[:payment_date].present?
        end
      end

      it 'returns nil' do
        expect(subject.education).to be_nil
      end
    end
  end
end
