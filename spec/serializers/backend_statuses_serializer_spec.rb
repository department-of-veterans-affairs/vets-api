# frozen_string_literal: true

require 'rails_helper'
require 'pagerduty/external_services/response'

describe BackendStatusesSerializer do
  subject { serialize(pagerduty_response, serializer_class: described_class) }

  let(:backend_status) { build_stubbed(:pagerduty_service) }
  let(:pagerduty_response) do
    PagerDuty::ExternalServices::Response.new(200, { statuses: [backend_status], reported_at: Time.current.iso8601 })
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :statuses' do
    expect(attributes['statuses'].size).to eq pagerduty_response.statuses.size
    expect(attributes['statuses'].first['service']).to eq backend_status.service
  end

  context 'when maintence_windows is present' do
    let(:maintenance_windows) { [build_stubbed(:maintenance_window)] }
    let(:rendered_hash) { serialize(pagerduty_response, { serializer_class: described_class, maintenance_windows: }) }
    let(:attributes_with_windows) { JSON.parse(rendered_hash)['data']['attributes'] }

    it 'includes :maintence_windows' do
      expect(attributes_with_windows['maintenance_windows'].size).to eq maintenance_windows.size
      expect(attributes_with_windows['maintenance_windows'].first['id']).to eq maintenance_windows.first.id
    end
  end

  context 'when mainteance_windows is not present' do
    it 'includes :maintence_windows as empty arrays' do
      expect(attributes['maintenance_windows']).to eq []
    end
  end
end
