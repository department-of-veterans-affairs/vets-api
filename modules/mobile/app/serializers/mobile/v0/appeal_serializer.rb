# frozen_string_literal: true

module Mobile
  module V0
    class AppealSerializer
      include JSONAPI::Serializer

      set_type :appeal
      attributes :appealIds, :active, :alerts, :aod, :aoj, :description, :docket, :events, :evidence,
                 :incompleteHistory, :issues, :location, :programArea, :status, :type, :updated
    end
  end
end
