# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/service'

describe EVSS::DisabilityCompensationForm::Service do
  let(:user) { build(:disabilities_compensation_user) }
  subject { described_class.new(user) }

  describe '#get_rated_disabilities' do
    context 'with a valid evss response' do
      it 'returns a rated disabilities response object' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          response = subject.get_rated_disabilities
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::RatedDisabilitiesResponse
          expect(response.rated_disabilities.count).to eq 2
          expect(response.rated_disabilities.first.special_issues).to be_an Array
          expect(response.rated_disabilities.first.special_issues.first)
            .to be_an EVSS::DisabilityCompensationForm::SpecialIssue
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      end

      it 'should log an error and raise GatewayTimeout' do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.get_rated_disabilities.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.get_rated_disabilities.total')
        expect { subject.get_rated_disabilities }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end

  describe '#submit_form' do
    let(:valid_form_content) { File.read 'spec/support/disability_compensation_submit_data.json' }
    context 'with valid input' do
      it 'returns a form submit response object' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          response = subject.submit_form(valid_form_content)
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::FormSubmitResponse
          expect(response.claim_id).to be_an Integer
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'should log an error and raise GatewayTimeout' do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.submit_form.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.submit_form.total')
        expect { subject.submit_form(valid_form_content) }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end
end
