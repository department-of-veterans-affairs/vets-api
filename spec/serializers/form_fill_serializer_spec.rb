# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ::Preneeds::FormFillSerializer, type: :serializer do
  let(:attachment_types) do
    Common::Collection.new(Preneeds::AttachmentType, data: attributes_for(:preneeds_attachment_type))
  end

  let(:branches_of_services) do
    Common::Collection.new(Preneeds::BranchesOfService, data: attributes_for(:branches_of_service))
  end

  let(:cemeteries) do
    Common::Collection.new(Preneeds::Cemetery, data: attributes_for(:cemetery))
  end

  let(:states) do
    Common::Collection.new(Preneeds::State, data: attributes_for(:preneeds_state))
  end

  let(:discharge_types) do
    Common::Collection.new(Preneeds::DischargeType, data: attributes_for(:discharge_type))
  end

  let(:form_fill) do
    VCR.use_cassette('preneeds/application_forms/new_pre_need_application_form') do
      Preneeds::FormFill.new
    end
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(form_fill, serializer_class: described_class) }

  before(:each) do
    allow_any_instance_of(Preneeds::Service).to receive(:expired?).and_return(true)
    allow_any_instance_of(Preneeds::Service).to receive(:get_attachment_types).and_return(attachment_types)
    allow_any_instance_of(Preneeds::Service).to receive(:get_branches_of_service).and_return(branches_of_services)
    allow_any_instance_of(Preneeds::Service).to receive(:get_cemeteries).and_return(cemeteries)
    allow_any_instance_of(Preneeds::Service).to receive(:get_states).and_return(states)
    allow_any_instance_of(Preneeds::Service).to receive(:get_discharge_types).and_return(discharge_types)
  end

  it 'serializes attributes' do
    expect(data['id']).to eq(form_fill.id)
    expect(attributes['attachment_types']).to eq(attachment_types.as_json)
    expect(attributes['branches_of_services']).to eq(branches_of_services.as_json)
    expect(attributes['cemeteries']).to eq(cemeteries.as_json)
    expect(attributes['states']).to eq(states.as_json)
    expect(attributes['discharge_types']).to eq(discharge_types.as_json)
  end
end
