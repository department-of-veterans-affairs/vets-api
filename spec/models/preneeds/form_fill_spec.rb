# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::FormFill do
  context 'with valid attributes' do
    subject { described_class.new }

    let(:params) { attributes_for :form_fill }

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

    it 'populates attributes' do
      allow_any_instance_of(Preneeds::Service).to receive(:expired?).and_return(true)
      allow_any_instance_of(Preneeds::Service).to receive(:get_attachment_types).and_return(attachment_types)
      allow_any_instance_of(Preneeds::Service).to receive(:get_branches_of_service).and_return(branches_of_services)
      allow_any_instance_of(Preneeds::Service).to receive(:get_cemeteries).and_return(cemeteries)
      allow_any_instance_of(Preneeds::Service).to receive(:get_states).and_return(states)
      allow_any_instance_of(Preneeds::Service).to receive(:get_discharge_types).and_return(discharge_types)

      expect(subject.id).to eq(Digest::SHA2.hexdigest(subject.to_json))

      expect(subject.attachment_types).to include(attachment_types.map { |at| at }.first)
      expect(subject.branches_of_services).to include(branches_of_services.map { |at| at }.first)
      expect(subject.cemeteries).to include(cemeteries.map { |at| at }.first)
      expect(subject.states).to include(states.map { |at| at }.first)
      expect(subject.discharge_types).to include(discharge_types.map { |at| at }.first)
    end
  end
end
