# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::Ch33BankAccountsController, type: :controller do
  let(:user) { FactoryBot.build(:ch33_dd_user) }

  before do
    sign_in_as(user)
  end

  context 'unauthorized user' do
    def self.expect_unauthorized
      it 'returns unauthorized' do
        get(:index)
        expect(response.status).to eq(403)
        put(:update)
        expect(response.status).to eq(403)
      end
    end

    context 'with a loa1 user' do
      let(:user) { build(:user, :loa1) }

      expect_unauthorized
    end

    context 'with a non idme user' do
      let(:user) { build(:user, :loa3, :mhv) }

      expect_unauthorized
    end
  end

  def expect_find_ch33_dd_eft_res
    expect(JSON.parse(response.body)).to eq(
      {
        'data' => {
          'id' => '', 'type' => 'hashes',
          'attributes' => {
            'account_type' => 'Checking',
            'account_number' => '123',
            'financial_institution_name' => 'BANK OF AMERICA, N.A.',
            'financial_institution_routing_number' => '*****0724'
          }
        }
      }
    )
  end

  describe '#index' do
    it 'returns the right data' do
      VCR.use_cassette('bgs/service/find_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        VCR.use_cassette('bgs/ddeft/find_bank_name_valid', VCR::MATCH_EVERYTHING) do
          get(:index)
        end
      end

      expect_find_ch33_dd_eft_res
    end
  end

  describe '#update' do
    def send_update
      put(
        :update,
        params: {
          account_type: 'Checking',
          account_number: '444',
          financial_institution_routing_number: '122239982'
        }
      )
    end

    def send_successful_update
      VCR.use_cassette('bgs/service/update_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        VCR.use_cassette('bgs/service/find_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('bgs/ddeft/find_bank_name_valid', VCR::MATCH_EVERYTHING) do
            send_update
          end
        end
      end
    end

    context 'with a successful update' do
      context 'if direct_deposit_vanotify flag is enabled' do
        it 'sends confirmation emails to the vanotify job' do
          Flipper.enable(:direct_deposit_vanotify)

          expect(VANotifyDdEmailJob).to receive(:send_to_emails).with(
            user.all_emails, :ch33
          )

          send_successful_update
        end
      end

      it 'sends confirmation emails' do
        Flipper.disable(:direct_deposit_vanotify)

        expect(DirectDepositEmailJob).to receive(:send_to_emails).with(
          user.all_emails, nil, :ch33
        )

        send_successful_update
      end

      it 'submits the update req and rerenders index' do
        send_successful_update

        expect_find_ch33_dd_eft_res
      end
    end

    context 'when there is an update error' do
      it 'renders the error message' do
        res = {
          update_ch33_dd_eft_response: {
            return: {
              return_code: 'F',
              error_message: 'Invalid routing number',
              return_message: 'FAILURE'
            },
            '@xmlns:ns0': 'http://services.share.benefits.vba.va.gov/'
          }
        }

        expect_any_instance_of(BGS::Service).to receive(:update_ch33_dd_eft).with(
          '122239982',
          '444',
          true
        ).and_return(
          OpenStruct.new(
            body: res
          )
        )

        send_update

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to eq(res.deep_stringify_keys)
      end
    end
  end
end
