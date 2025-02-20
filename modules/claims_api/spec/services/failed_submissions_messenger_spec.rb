# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Slack::FailedSubmissionsMessenger do
  let(:notifier) { instance_double(ClaimsApi::Slack::Client) }

  before do
    allow(ClaimsApi::Slack::Client).to receive(:new).and_return(notifier)
  end

  context 'when there is one type of each error' do
    let(:errored_disability_claims) { Array.new(1) { SecureRandom.uuid } }
    let(:errored_va_gov_claims) { Array.new(1) { SecureRandom.uuid } }
    let(:errored_poa) { Array.new(1) { SecureRandom.uuid } }
    let(:errored_itf) { Array.new(1) { SecureRandom.uuid } }
    let(:errored_ews) { Array.new(1) { SecureRandom.uuid } }
    let(:from) { '03:59PM EST' }
    let(:to) { '04:59PM EST' }
    let(:environment) { 'production' }

    it 'sends a well formatted slack message' do
      messenger = described_class.new(
        errored_disability_claims: errored_disability_claims,
        errored_va_gov_claims: errored_va_gov_claims,
        errored_poa: errored_poa,
        errored_itf: errored_itf,
        errored_ews: errored_ews,
        from: from,
        to: to,
        environment: environment
      )

      expect(notifier).to receive(:notify) do |_text, args|
        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('ERRORED SUBMISSIONS', from, to, environment)
            }
          )
        )

        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('Disability Compensation Errors', 'Total: 1')
            }
          )
        )

        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('Va Gov Disability Compensation Errors', 'Total: 1')
            }
          )
        )

        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('Power of Attorney Errors', 'Total: 1')
            }
          )
        )

        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('Intent to File Errors', 'Total: 1')
            }
          )
        )

        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('Evidence Waiver Errors', 'Total: 1')
            }
          )
        )

        # title block + 1 totals block for each error type + 1 block for each error EXCEPT intent to file
        expect(args[:blocks]).to have_attributes(size: 1 + 5 + 4)
      end

      messenger.notify!
    end
  end

  context 'when there are more than 10 failed va.gov submissions' do
    let(:num_errors) { 12 }
    let(:errored_va_gov_claims) { Array.new(num_errors) { SecureRandom.uuid } }
    let(:from) { '03:59PM EST' }
    let(:to) { '04:59PM EST' }
    let(:environment) { 'production' }

    it 'sends error ids with links to logs' do
      messenger = described_class.new(
        errored_va_gov_claims: errored_va_gov_claims,
        from: from,
        to: to,
        environment: environment
      )

      expect(notifier).to receive(:notify) do |_text, args|
        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('ERRORED SUBMISSIONS', from, to, environment)
            }
          )
        )

        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('Va Gov Disability Compensation Errors', "Total: #{num_errors}")
            }
          )
        )

        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including('```', '<https://vagov.ddog-gov.com/logs?query=',
                                       "|#{errored_va_gov_claims.first}>", '```')
            }
          )
        )

        # title block + total errors block + 1 block per 5 errors
        expect(args[:blocks]).to have_attributes(size: 2 + (num_errors / 5) + ((num_errors % 5).zero? ? 0 : 1))
      end

      messenger.notify!
    end

    context 'when there are intent to file errors' do
      let(:num_errors) { 100 }
      let(:errored_itf) { Array.new(num_errors) { SecureRandom.uuid } }

      it 'only sends the title and total block' do
        messenger = described_class.new(
          errored_itf: errored_itf
        )

        expect(notifier).to receive(:notify) do |_text, args|
          expect(args[:blocks]).to include(
            a_hash_including(
              text: {
                type: 'mrkdwn',
                text: a_string_including('Intent to File Errors', "Total: #{num_errors}")
              }
            )
          )

          # title block + total errors block
          expect(args[:blocks]).to have_attributes(size: 2)
        end

        messenger.notify!
      end
    end
  end
end
