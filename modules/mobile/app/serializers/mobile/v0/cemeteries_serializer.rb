# frozen_string_literal: true

module Mobile
  module V0
    class CemeteriesSerializer
      include JSONAPI::Serializer

      set_type :cemetery

      set_id :id

      attribute :name
      attribute :type

      def initialize(cemeteries_info)
        resource = cemeteries_info.records.map do |cemetery_info|
          CemeteriesStruct.new(id: cemetery_info.num,
                               name: cemetery_info.name,
                               type: cemetery_info.cemetery_type)
        end

        super(resource)
      end
    end

    CemeteriesStruct = Struct.new(:id, :name, :type)
  end
end
