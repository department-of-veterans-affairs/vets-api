# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Slack::FailedSubmissionsMessenger do
  let(:notifier) { instance_double(ClaimsApi::Slack::Client) }

  before do
    allow(ClaimsApi::Slack::Client).to receive(:new).and_return(notifier)
  end

  context 'when there is one type of each error' do
    let(:errored_disability_claims) { Array.new(1) { SecureRandom.uuid } }
    let(:errored_va_gov_claims) { Array.new(1) { "FORM526SUBMISSION-#{SecureRandom.uuid}" } }
    let(:errored_poa) { Array.new(1) { SecureRandom.uuid } }
    let(:errored_itf) { Array.new(1) { SecureRandom.uuid } }
    let(:errored_ews) { Array.new(1) { SecureRandom.uuid } }
    let(:from) { '03:59PM EST' }
    let(:to) { '04:59PM EST' }
    let(:environment) { 'production' }

    it 'sends a well formatted slack message' do
      messenger = described_class.new(
        errored_disability_claims:,
        errored_va_gov_claims:,
        errored_poa:,
        errored_itf:,
        errored_ews:,
        from:,
        to:,
        environment:
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

  context 'when there are more than 10 failed va.gov submissions & TID is in whitelist' do
    let(:num_errors) { 12 }
    let(:tid_tag) { "FORM526SUBMISSION-#{SecureRandom.uuid}" }
    let(:errored_va_gov_claims) do
      Array.new(num_errors) { "'#{tid_tag}, extra: data, to: ignore'" }
    end
    let(:from) { '03:59PM EST' }
    let(:to) { '04:59PM EST' }
    let(:environment) { 'production' }

    it 'sends error ids with links to logs' do
      messenger = described_class.new(
        errored_va_gov_claims:,
        from:,
        to:,
        environment:
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
              text: a_string_including('```',
                                       "TID: <https://vagov.ddog-gov.com/logs?query='#{tid_tag}'",
                                       '```')
            }
          )
        )

        # title block + total errors block + 1 block per 5 errors
        expect(args[:blocks]).to have_attributes(size: 2 + (num_errors / 5) + ((num_errors % 5).zero? ? 0 : 1))
      end

      messenger.notify!
    end

    context 'if transaction ids are not in the substring whitelist' do
      let(:num_errors) { 1 }

      [nil, SecureRandom.uuid, 'NOT_WHITELISTED_TAG'].each do |tid|
        it 'avoids linking to logs that are not there' do
          errored_va_gov_claims = [tid]
          messenger = described_class.new(
            errored_va_gov_claims:,
            from: '03:59PM EST',
            to: '04:59PM EST',
            environment: 'production'
          )

          expect(notifier).to receive(:notify) do |_text, args|
            expected_link_text = if tid.blank?
                                   'TID: N/A'
                                 else
                                   "TID: <https://vagov.ddog-gov.com/logs?query='#{tid}'"
                                 end

            expect(args[:blocks]).to include(
              a_hash_including(
                text: {
                  type: 'mrkdwn',
                  text: a_string_including('```', expected_link_text, '```')
                }
              )
            )
          end

          messenger.notify!
        end
      end
    end

    context 'when there are intent to file errors' do
      let(:num_errors) { 100 }
      let(:errored_itf) { Array.new(num_errors) { SecureRandom.uuid } }

      it 'only sends the title and total block' do
        messenger = described_class.new(
          errored_itf:
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

  describe '#general_datadog_link' do
    let(:messenger) do
      described_class.new(
        from: '03:59PM EST',
        to: '04:59PM EST',
        environment: 'production'
      )
    end

    it 'returns a properly formatted DataDog URL' do
      # Mock the current time for consistent testing
      allow(Time).to receive(:now).and_return(Time.zone.at(1_640_995_200)) # 2022-01-01 00:00:00 UTC

      link = messenger.send(:general_datadog_link)

      expect(link).to include('https://vagov.ddog-gov.com/logs')
      expect(link).to include('query=service%3Avets-api%20status%3Aerror')
      expect(link).to include('from_ts=1640736000000') # 3 days ago in milliseconds
      expect(link).to include('to_ts=1640995200000')   # current time in milliseconds
      expect(link).to include('View All Errors in DataDog')
    end

    it 'includes the general DataDog link in the message heading' do
      allow(Time).to receive(:now).and_return(Time.zone.at(1_640_995_200))

      expect(notifier).to receive(:notify) do |_text, args|
        expect(args[:blocks]).to include(
          a_hash_including(
            text: {
              type: 'mrkdwn',
              text: a_string_including(
                'ERRORED SUBMISSIONS',
                'View All Errors in DataDog',
                'https://vagov.ddog-gov.com/logs'
              )
            }
          )
        )
      end

      messenger.notify!
    end
  end
end
