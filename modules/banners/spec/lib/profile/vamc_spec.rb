# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Banners::Profile::Vamc do
  describe '.parsed_banner' do
    let(:graphql_response) do
      {
        'entityId' => '123',
        'title' => 'Sample Title',
        'fieldAlertType' => 'warning',
        'fieldBody' => { 'processed' => 'Sample content' },
        'fieldBannerAlertVamcs' => [
          {
            'entity' => {
              'fieldOffice' => {
                'entity' => {
                  'entityUrl' => { 'path' => '/specific-path' }
                }
              },
              'entityUrl' => { 'path' => '/general-path' }
            }
          }
        ],
        'fieldAlertDismissable' => true,
        'fieldAlertOperatingStatusCta' => 'Status CTA',
        'fieldAlertEmailUpdatesButton' => 'Email CTA',
        'fieldAlertFindFacilitiesCta' => 'Find CTA',
        'fieldAlertInheritanceSubpages' => true
      }
    end

    it 'returns a correctly formatted banner hash' do
      expected = {
        entity_id: '123',
        headline: 'Sample Title',
        alert_type: 'warning',
        entity_bundle: 'full_width_banner_alert',
        content: 'Sample content',
        context: graphql_response['fieldBannerAlertVamcs'],
        show_close: true,
        operating_status_cta: 'Status CTA',
        email_updates_button: 'Email CTA',
        find_facilities_cta: 'Find CTA',
        limit_subpage_inheritance: true,
        path: '/specific-path'
      }

      expect(described_class.parsed_banner(graphql_response)).to eq(expected)
    end
  end

  describe '.parsed_path' do
    context 'when vamc_list has a specific entity path' do
      let(:vamc_list) do
        [
          {
            'entity' => {
              'fieldOffice' => {
                'entity' => {
                  'entityUrl' => { 'path' => '/specific-path' }
                }
              },
              'entityUrl' => { 'path' => '/general-path' }
            }
          }
        ]
      end

      it 'returns the specific entity path' do
        expect(described_class.parsed_path(vamc_list)).to eq('/specific-path')
      end
    end

    context 'when vamc_list has only a general entity path' do
      let(:vamc_list) do
        [
          {
            'entity' => {
              'entityUrl' => { 'path' => '/general-path' }
            }
          }
        ]
      end

      it 'returns the general entity path' do
        expect(described_class.parsed_path(vamc_list)).to eq('/general-path')
      end
    end

    context 'when vamc_list is not an array or is empty' do
      it 'returns nil when vamc_list is not an array' do
        expect(described_class.parsed_path(nil)).to be_nil
        expect(described_class.parsed_path({})).to be_nil
      end

      it 'returns nil when vamc_list is empty' do
        expect(described_class.parsed_path([])).to be_nil
      end
    end
  end
end
