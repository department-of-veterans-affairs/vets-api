# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/local_bgs_proxy'

describe ClaimsApi::LocalBGSProxy do
  subject do
    described_class.new(
      external_uid: nil,
      external_key: nil
    )
  end

  expected_instance_methods = {
    construct_itf_body: %i[options],
    convert_nil_values: %i[options],
    find_intent_to_file_by_ptcpnt_id_itf_type_cd: %i[id type],
    find_poa_by_participant_id: %i[id],
    find_poa_history_by_ptcpnt_id: %i[id],
    find_tracked_items: %i[id],
    healthcheck: %i[endpoint],
    insert_intent_to_file: %i[options],
    jrn: %i[],
    make_request: [endpoint: nil, action: nil, body: nil],
    to_camelcase: [claim: nil],
    transform_bgs_claim_to_evss: %i[claim],
    transform_bgs_claims_to_evss: %i[claims],
    validate_opts!: %i[opts required_keys]
  }

  expected_instance_methods.each_value(&:freeze)
  expected_instance_methods.freeze

  it 'defines the correct set of instance methods' do
    actual = described_class.instance_methods(false) - [:proxied]
    expect(actual).to match_array(expected_instance_methods.keys)
  end

  describe 'claims_api_local_bgs_refactor feature toggling' do
    before do
      expect(Flipper).to(
        receive(:enabled?)
          .with(:claims_api_local_bgs_refactor)
          .and_return(toggle)
      )
    end

    define_singleton_method(:it_delegates_every_instance_method) do |to:|
      it "has a proxied of type #{to}" do
        expect(subject.proxied).to be_a(to)
      end

      expected_instance_methods.each do |meth, args|
        describe "when instance method is `#{meth}`" do
          it "delegates to `#{to}`" do
            if args.empty?
              expect(subject.proxied).to receive(meth).with(no_args).once
              subject.send(meth)
            else
              args = args.deep_dup
              kwargs = args.extract_options!
              expect(subject.proxied).to receive(meth).with(*args, **kwargs).once
              subject.send(meth, *args, **kwargs)
            end
          end
        end
      end
    end

    describe 'with refactor toggled off' do
      let(:toggle) { false }

      it_delegates_every_instance_method(
        to: ClaimsApi::LocalBGS
      )
    end

    describe 'with refactor toggled on' do
      let(:toggle) { true }

      it_delegates_every_instance_method(
        to: ClaimsApi::LocalBGSRefactored
      )
    end
  end
end
