# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    module Form21aUploadConcern
      extend ActiveSupport::Concern

      DOCUMENT_KEYS = {
        'conviction-details' => 'imprisonedDetailsDocuments',
        'court-martialed-details' => 'militaryConvictionDetailsDocuments',
        'under-charges-details' => 'currentlyChargedDetailsDocuments',
        'resigned-from-education-details' => 'suspendedDetailsDocuments',
        'withdrawn-from-education-details' => 'withdrawnDetailsDocuments',
        'disciplined-for-dishonesty-details' => 'disciplinedDetailsDocuments',
        'resigned-for-dishonesty-details' => 'resignedRetiredDetailsDocuments',
        'representative-for-agency-details' => 'agentAttorneyDetailsDocuments',
        'reprimanded-in-agency-details' => 'reprimandedDetailsDocuments',
        'resigned-from-agency-details' => 'resignedToAvoidReprimandDetailsDocuments',
        'applied-for-va-accreditation-details' => 'appliedForAccreditationDetailsDocuments',
        'terminated-by-vsorg-details' => 'accreditationTerminatedDetailsDocuments',
        'condition-that-affects-representation-details' => 'impairmentsDetailsDocuments'
      }.freeze

      def documents_key_for(slug)
        DOCUMENT_KEYS.fetch(slug) do
          raise ArgumentError, "Unknown details slug: #{slug}"
        end
      end
    end
  end
end
