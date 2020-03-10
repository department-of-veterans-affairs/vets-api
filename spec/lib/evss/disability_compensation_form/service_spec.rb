# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/service'

describe EVSS::DisabilityCompensationForm::Service do
  subject do
    described_class.new(
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    )
  end

  let(:user) { build(:disabilities_compensation_user) }

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

      it 'logs an error and raise GatewayTimeout' do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.get_rated_disabilities.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.get_rated_disabilities.total')
        expect { subject.get_rated_disabilities }.to raise_error(Common::Exceptions::GatewayTimeout)
      end

      context 'Timeout triggers log' do
        let(:last_pii_log) do
          subject.get_rated_disabilities
          false
        rescue
          PersonalInformationLog.last
        end
        it 'records to PII log' do
          expect(last_pii_log).not_to be nil
        end
      end
    end
  end

  describe '#submit_form' do
    let(:valid_form_content) do
      File.read 'spec/support/disability_compensation_form/front_end_submission_with_uploads.json'
    end

    context 'with valid input' do
      it 'returns a form submit response object' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form_v2') do
          response = subject.submit_form526(valid_form_content)
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

      it 'logs an error and raise GatewayTimeout' do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.submit_form526.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.submit_form526.total')
        expect { subject.submit_form526(valid_form_content) }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end

  describe '.response_json' do
    subject { EVSS::DisabilityCompensationForm::Service.response_json(response) }

    let(:response_methods) { %i[to_hash status body headers as_json to_h] }

    let(:dummy_response) do
      Struct.new(*response_methods).new(*response_methods)
    end

    let(:response) do
      resp = dummy_response
      Array.wrap(without).each { |method| resp.instance_eval("undef :#{method}", __FILE__, __LINE__) }
      resp
    end

    let(:without) { [] }

    it { is_expected.to eq(response.to_hash) }

    context 'without #to_hash' do
      let(:without) { :to_hash }

      it do
        expect(subject).to eq(
          status: response.status,
          body: response.body,
          headers: response.headers
        )
      end
    end

    context 'without #to_hash #status' do
      let(:without) { %i[to_hash status] }

      it { is_expected.to eq(response.as_json) }
    end

    context 'without #to_hash #body' do
      let(:without) { %i[to_hash body] }

      it { is_expected.to eq(response.as_json) }
    end

    context 'without #to_hash #headers' do
      let(:without) { %i[to_hash headers] }

      it { is_expected.to eq(response.as_json) }
    end

    context 'without #to_hash #status #body' do
      let(:without) { %i[to_hash status body] }

      it { is_expected.to eq(response.as_json) }
    end

    context 'without #to_hash #status headers' do
      let(:without) { %i[to_hash status headers] }

      it { is_expected.to eq(response.as_json) }
    end

    context 'without #to_hash #status #body #headers' do
      let(:without) { %i[to_hash status body headers] }

      it { is_expected.to eq(response.as_json) }
    end

    context 'without #to_hash #status #body #headers #as_json' do
      let(:without) { %i[to_hash status body headers as_json] }

      it { is_expected.to eq(response.to_h) }
    end

    context 'without #to_hash #status #body #headers #as_json #to_h' do
      let(:without) { %i[to_hash status body headers as_json to_h] }

      it { is_expected.to eq('failed to turn response into json') }
    end
  end

  describe '.error_json' do
    subject { EVSS::DisabilityCompensationForm::Service.error_json(error) }

    let(:error) { StandardError.new }

    let(:error_hash) do
      {
        error_class: error.class.to_s,
        message: error.message,
        backtrace: error.backtrace
      }
    end

    it { is_expected.to eq(error_hash) }

    context 'Net::ReadTimeout' do
      let(:error) { Net::ReadTimeout.new }

      it { is_expected.to eq(error_hash) }
    end

    context 'Faraday::TimeoutError' do
      let(:error) { Faraday::TimeoutError.new }

      it { is_expected.to eq(error_hash) }
    end

    context 'Timeout::Error' do
      let(:error) { Timeout::Error.new }

      it { is_expected.to eq(error_hash) }
    end

    context 'some other error' do
      let(:error) do
        Float 'cat'
      rescue => e
        e
      end

      it do
        expect(subject[:error_class]).not_to be_nil
        expect(subject[:message]).not_to be_nil
        expect(subject[:backtrace]).not_to be_nil
      end
    end
  end
end
