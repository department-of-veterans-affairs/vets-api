# frozen_string_literal: true

require 'rails_helper'
require 'identity/parsers/gc_ids'

describe Identity::Parsers::GCIds do
  let(:class_instance) { Class.new { extend Identity::Parsers::GCIds } }
  let(:va_root_oid) { Identity::Parsers::GCIds::VA_ROOT_OID }
  let(:dod_root_oid) { Identity::Parsers::GCIds::DOD_ROOT_OID }

  describe '#parse_xml_gcids' do
    subject { class_instance.parse_xml_gcids(ids) }

    context 'when input ids is an empty array' do
      let(:expected_empty_id_hash) do
        {
          icn: nil,
          sec_id: nil,
          mhv_ids: nil,
          active_mhv_ids: nil,
          edipi: nil,
          vba_corp_id: nil,
          idme_id: nil,
          vha_facility_ids: nil,
          cerner_facility_ids: nil,
          cerner_id: nil,
          birls_ids: nil,
          vet360_id: nil,
          icn_with_aaid: nil,
          birls_id: nil
        }
      end
      let(:ids) { [] }

      it 'returns a hash with nil ids' do
        expect(subject).to eq expected_empty_id_hash
      end
    end

    context 'when input ids is not an Array' do
      let(:ids) { 'banana' }

      it 'returns nil' do
        expect(subject).to eq nil
      end
    end

    context 'when input ids is an array of Ox::Element objects' do
      let(:ids) { [OpenStruct.new(attributes: { extension: id_object, root: root_oid })] }
      let(:id) { '123454321' }
      let(:root_oid) { va_root_oid }

      context 'and the format of the ids matches the icn regex' do
        let(:id_object) { "#{id}^NI^200M^USVHA^P" }

        it 'returns a parsed icn id from the input xml object' do
          expect(subject[:icn]).to eq id
        end
      end

      context 'and the format of the ids matches the sec id regex' do
        let(:id_object) { "#{id}^PN^200PROV^USDVA^A" }

        it 'returns a parsed sec id from the input xml object' do
          expect(subject[:sec_id]).to eq id
        end
      end

      context 'and the format of the ids matches the mhv ids regex' do
        let(:id_object) { "#{id}^PI^200MHV^USVHA^P" }

        it 'returns a parsed mhv ids array from the input xml object' do
          expect(subject[:mhv_ids]).to eq [id]
        end
      end

      context 'and the format of the ids matches the active mhv ids regex' do
        let(:id_object) { "#{id}^PI^200MHV^USVHA^A" }

        it 'returns a parsed active mhv ids array from the input xml object' do
          expect(subject[:active_mhv_ids]).to eq [id]
        end
      end

      context 'and the format of the ids matches the edipi regex' do
        let(:id_object) { "#{id}^NI^200DOD^USDOD^A" }

        context 'and the root is equal to the DOD_ROOT_OID constant' do
          let(:root_oid) { dod_root_oid }

          it 'returns a parsed edipi from the input xml object' do
            expect(subject[:edipi]).to eq id
          end
        end

        context 'and the root input is not equal to the DOD_ROOT_OID constant' do
          it 'returns nil' do
            expect(subject[:edipi]).to eq nil
          end
        end
      end

      context 'and the format of the ids matches the vba_corp id regex' do
        let(:id_object) { "#{id}^PI^200CORP^USVBA^A" }

        it 'returns a parsed vba_corp id from the input xml object' do
          expect(subject[:vba_corp_id]).to eq id
        end
      end

      context 'and the format of the ids matches the idme id regex' do
        let(:id_object) { "#{id}^PN^200VIDM^USDVA^A" }

        it 'returns a parsed idme id from the input xml object' do
          expect(subject[:idme_id]).to eq id
        end
      end

      context 'and the format of the ids matches the vha facility ids regex' do
        let(:id_object) { "#{id}^PI^#{facility_id}^USVHA^A" }
        let(:facility_id) { '200MHV' }

        it 'returns a parsed vha facility id from the input xml object' do
          expect(subject[:vha_facility_ids]).to eq [facility_id]
        end
      end

      context 'and the format of the ids matches the cerner facility ids regex' do
        let(:id_object) { "#{id}^PI^#{facility_id}^USVHA^C" }
        let(:facility_id) { '200MHV' }

        it 'returns a parsed cerner facility ids from the input xml object' do
          expect(subject[:cerner_facility_ids]).to eq [facility_id]
        end
      end

      context 'and the format of the ids matches the cerner id regex' do
        let(:id_object) { "#{id}^PI^200CRNR^USVHA^A" }

        it 'returns a parsed cerner id from the input xml object' do
          expect(subject[:cerner_id]).to eq id
        end
      end

      context 'and the format of the ids matches the birls ids regex' do
        let(:id_object) { "#{id}^PI^200BRLS^USVBA^A" }

        it 'returns a parsed birls ids array from the input xml object' do
          expect(subject[:birls_ids]).to eq [id]
        end

        it 'returns a parsed birls id from the input xml object' do
          expect(subject[:birls_id]).to eq id
        end
      end

      context 'and the format of the ids matches the vet360 id regex' do
        let(:id_object) { "#{id}^PI^200VETS^USDVA^A" }

        it 'returns a parsed vet360 id from the input xml object' do
          expect(subject[:vet360_id]).to eq id
        end
      end

      context 'and the format of the ids matches the permanent icn id regex' do
        let(:id_object) { "#{expected_response}^#{status}" }
        let(:expected_response) { "#{id}^NI^200M^USVHA" }

        context 'and status for id is P' do
          let(:status) { 'P' }

          it 'returns a parsed identifier with status removed from the input xml object' do
            expect(subject[:icn_with_aaid]).to eq expected_response
          end
        end

        context 'and status for id is an arbitrary value' do
          let(:status) { 'BANANA' }

          it 'returns nil' do
            expect(subject[:icn_with_aaid]).to eq nil
          end
        end
      end
    end
  end

  describe '#parse_xml_historical_icns' do
    subject { class_instance.parse_xml_historical_icns(historical_icn_ids) }

    context 'when input historical icn ids is an empty array' do
      let(:historical_icn_ids) { [] }

      it 'returns an empty array' do
        expect(subject).to eq []
      end
    end

    context 'when input historical icn ids is not an Array' do
      let(:historical_icn_ids) { 'banana' }

      it 'returns an empty array' do
        expect(subject).to eq []
      end
    end

    context 'when input historical icn ids is an array of Ox::Element objects' do
      let(:historical_icn_ids) { [Ox.parse(xml_object)] }
      let(:xml_object) { "<id root='#{va_root_oid}' extension='#{icn_object}'/>" }

      context 'and the format of the ids matches the historical icn ids regex' do
        let(:icn_object) { "#{icn}^NI^200M^USVHA^A" }
        let(:icn) { '16701377' }

        it 'returns a parsed icn id from the input xml object' do
          expect(subject).to eq [icn]
        end
      end

      context 'and the format of the ids does not match the historical icn ids regex' do
        let(:icn_object) { 'banana' }

        it 'returns an empty array' do
          expect(subject).to eq []
        end
      end
    end
  end

  describe '#parse_string_gcids' do
    subject { class_instance.parse_string_gcids(ids, root_oid) }

    context 'when input ids is nil' do
      let(:ids) { nil }
      let(:root_oid) { nil }

      it 'returns nil' do
        expect(subject).to eq nil
      end
    end

    context 'when input ids is a string of ids' do
      let(:ids) { "#{id_object}|some-other-id-object" }
      let(:id) { '123454321' }
      let(:root_oid) { va_root_oid }

      context 'and the format of the ids matches the icn regex' do
        let(:id_object) { "#{id}^NI^200M^USVHA^P" }

        it 'returns a parsed icn id from the input xml object' do
          expect(subject[:icn]).to eq id
        end
      end

      context 'and the format of the ids matches the sec id regex' do
        let(:id_object) { "#{id}^PN^200PROV^USDVA^A" }

        it 'returns a parsed sec id from the input xml object' do
          expect(subject[:sec_id]).to eq id
        end
      end

      context 'and the format of the ids matches the mhv ids regex' do
        let(:id_object) { "#{id}^PI^200MHV^USVHA^P" }

        it 'returns a parsed mhv ids array from the input xml object' do
          expect(subject[:mhv_ids]).to eq [id]
        end
      end

      context 'and the format of the ids matches the active mhv ids regex' do
        let(:id_object) { "#{id}^PI^200MHV^USVHA^A" }

        it 'returns a parsed active mhv ids array from the input xml object' do
          expect(subject[:active_mhv_ids]).to eq [id]
        end
      end

      context 'and the format of the ids matches the edipi regex' do
        let(:id_object) { "#{id}^NI^200DOD^USDOD^A" }

        context 'and the root is equal to the DOD_ROOT_OID constant' do
          let(:root_oid) { dod_root_oid }

          it 'returns a parsed edipi from the input xml object' do
            expect(subject[:edipi]).to eq id
          end
        end

        context 'and the root input is not equal to the DOD_ROOT_OID constant' do
          it 'returns nil' do
            expect(subject[:edipi]).to eq nil
          end
        end
      end

      context 'and the format of the ids matches the vba_corp id regex' do
        let(:id_object) { "#{id}^PI^200CORP^USVBA^A" }

        it 'returns a parsed vba_corp id from the input xml object' do
          expect(subject[:vba_corp_id]).to eq id
        end
      end

      context 'and the format of the ids matches the idme id regex' do
        let(:id_object) { "#{id}^PN^200VIDM^USDVA^A" }

        it 'returns a parsed idme id from the input xml object' do
          expect(subject[:idme_id]).to eq id
        end
      end

      context 'and the format of the ids matches the vha facility ids regex' do
        let(:id_object) { "#{id}^PI^#{facility_id}^USVHA^A" }
        let(:facility_id) { '200MHV' }

        it 'returns a parsed vha facility id from the input xml object' do
          expect(subject[:vha_facility_ids]).to eq [facility_id]
        end
      end

      context 'and the format of the ids matches the cerner facility ids regex' do
        let(:id_object) { "#{id}^PI^#{facility_id}^USVHA^C" }
        let(:facility_id) { '200MHV' }

        it 'returns a parsed cerner facility ids from the input xml object' do
          expect(subject[:cerner_facility_ids]).to eq [facility_id]
        end
      end

      context 'and the format of the ids matches the cerner id regex' do
        let(:id_object) { "#{id}^PI^200CRNR^USVHA^A" }

        it 'returns a parsed cerner id from the input xml object' do
          expect(subject[:cerner_id]).to eq id
        end
      end

      context 'and the format of the ids matches the birls ids regex' do
        let(:id_object) { "#{id}^PI^200BRLS^USVBA^A" }

        it 'returns a parsed birls ids array from the input xml object' do
          expect(subject[:birls_ids]).to eq [id]
        end

        it 'returns a parsed birls id from the input xml object' do
          expect(subject[:birls_id]).to eq id
        end
      end

      context 'and the format of the ids matches the vet360 id regex' do
        let(:id_object) { "#{id}^PI^200VETS^USDVA^A" }

        it 'returns a parsed vet360 id from the input xml object' do
          expect(subject[:vet360_id]).to eq id
        end
      end

      context 'and the format of the ids matches the permanent icn id regex' do
        let(:id_object) { "#{expected_response}^#{status}" }
        let(:expected_response) { "#{id}^NI^200M^USVHA" }

        context 'and status for id is P' do
          let(:status) { 'P' }

          it 'returns a parsed identifier with status removed from the input xml object' do
            expect(subject[:icn_with_aaid]).to eq expected_response
          end
        end

        context 'and status for id is an arbitrary value' do
          let(:status) { 'BANANA' }

          it 'returns nil' do
            expect(subject[:icn_with_aaid]).to eq nil
          end
        end
      end
    end
  end
end
