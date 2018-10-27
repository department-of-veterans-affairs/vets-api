# frozen_string_literal: true

module V0
  class ApidocsController < ApplicationController
    include Swagger::Blocks

    skip_before_action :authenticate

    swagger_root do
      key :swagger, '2.0'
      info do
        key :version, '1.0.0'
        key :title, 'vets.gov API'
        key :description, 'The API for managing vets.gov'
        key :termsOfService, ''
        contact do
          key :name, 'vets.gov team'
        end
        license do
          key :name, 'Creative Commons Zero v1.0 Universal'
        end
      end
      # Tags are used to group endpoints in tools like swagger-ui
      # Groups/tags are displayed in the order declared here, followed
      # by the order they first appear in the swaggered_classes below, so
      # declare all tags here in desired order.
      tag do
        key :name, 'authentication'
        key :description, 'Authentication operations'
      end
      tag do
        key :name, 'user'
        key :description, 'Current authenticated user data'
      end
      tag do
        key :name, 'profile'
        key :description, 'User profile information'
      end
      tag do
        key :name, 'benefits_info'
        key :description, 'Veteran benefits profile information'
      end
      tag do
        key :name, 'benefits_forms'
        key :description, 'Apply for and claim Veteran benefits'
      end
      tag do
        key :name, 'benefits_status'
        key :description, 'Check status of benefits claims and appeals'
      end
      tag do
        key :name, 'form_526'
        key :description, 'Creating and submitting compensation applications'
      end
      tag do
        key :name, 'prescriptions'
        key :description, 'Prescription refill/tracking operations'
      end
      tag do
        key :name, 'health_records'
        key :description, 'Download electronic health records'
      end
      tag do
        key :name, 'secure_messaging'
        key :description, 'Send and receive secure messages to health providers'
      end
      tag do
        key :name, 'terms_and_conditions'
        key :description, 'Terms and conditions acceptance for access to health tools'
      end
      tag do
        key :name, 'facilities'
        key :description, 'VA facilities, locations, hours of operation, available services'
      end
      tag do
        key :name, 'gi_bill_institutions'
        key :description, 'Discover institutions at which GI Bill benefits may be used'
      end
      tag do
        key :name, 'in_progress_forms'
        key :description, 'In-progress form operations'
      end
      tag do
        key :name, 'site'
        key :description, 'Site service availability and feedback'
      end
      key :host, Settings.hostname
      key :schemes, %w[https http]
      key :basePath, '/'
      key :consumes, ['application/json']
      key :produces, ['application/json']

      [true, false].each do |required|
        parameter :"#{required ? '' : 'optional_'}authorization" do
          key :name, 'Authorization'
          key :in, :header
          key :description, 'The authorization method and token value'
          key :required, required
          key :type, :string
        end
      end

      parameter :optional_page_number, name: :page, in: :query, required: false, type: :integer,
                                       description: 'Page of results, greater than 0 (default: 1)'

      parameter :optional_page_length, name: :per_page, in: :query, required: false, type: :integer,
                                       description: 'number of results, between 1 and 99 (default: 10)'

      parameter :optional_sort, name: :sort, in: :query, required: false, type: :string,
                                description: "Comma separated sort field(s), prepend with '-' for descending"

      parameter :optional_filter, name: :filter, in: :query, required: false, type: :string,
                                  description: 'Filter on refill_status: [[refill_status][logical operator]=status]'
    end

    # A list of all classes that have swagger_* declarations.
    SWAGGERED_CLASSES = [
      Swagger::Requests::Address,
      Swagger::Requests::Appeals,
      Swagger::Requests::Appointments,
      Swagger::Requests::BackendStatuses,
      Swagger::Requests::BB::HealthRecords,
      Swagger::Requests::BurialClaims,
      Swagger::Requests::DisabilityCompensationForm,
      Swagger::Requests::EducationBenefitsClaims,
      Swagger::Requests::Feedbacks,
      Swagger::Requests::Gibct::CalculatorConstants,
      Swagger::Requests::Gibct::Institutions,
      Swagger::Requests::HealthCareApplications,
      Swagger::Requests::InProgressForms,
      Swagger::Requests::IntentToFile,
      Swagger::Requests::Letters,
      Swagger::Requests::MaintenanceWindows,
      Swagger::Requests::Messages::Folders,
      Swagger::Requests::Messages::Messages,
      Swagger::Requests::Messages::MessageDrafts,
      Swagger::Requests::Messages::TriageTeams,
      Swagger::Requests::PensionClaims,
      Swagger::Requests::PerformanceMonitoring,
      Swagger::Requests::Post911GiBillStatuses,
      Swagger::Requests::PPIU,
      Swagger::Requests::Prescriptions::Prescriptions,
      Swagger::Requests::Prescriptions::Trackings,
      Swagger::Requests::Profile,
      Swagger::Requests::Search,
      Swagger::Requests::Sessions,
      Swagger::Requests::TermsAndConditions,
      Swagger::Requests::UploadSupportingEvidence,
      Swagger::Requests::User,
      Swagger::Requests::VAFacilities,
      Swagger::Requests::CCProviders,
      Swagger::Responses::AuthenticationError,
      Swagger::Responses::SavedForm,
      Swagger::Schemas::Address,
      Swagger::Schemas::Appeals,
      Swagger::Schemas::AsyncTransaction::Vet360,
      Swagger::Schemas::BB::HealthRecords,
      Swagger::Schemas::Countries,
      Swagger::Schemas::RatedDisabilities,
      Swagger::Schemas::Email,
      Swagger::Schemas::Errors,
      Swagger::Schemas::EVSSAuthError,
      Swagger::Schemas::Gibct::CalculatorConstants,
      Swagger::Schemas::Gibct::Institutions,
      Swagger::Schemas::Health::Folders,
      Swagger::Schemas::Health::Links,
      Swagger::Schemas::Health::Messages,
      Swagger::Schemas::Health::Meta,
      Swagger::Schemas::Health::Prescriptions,
      Swagger::Schemas::Health::Trackings,
      Swagger::Schemas::Health::TriageTeams,
      Swagger::Schemas::IntentToFile,
      Swagger::Schemas::LetterBeneficiary,
      Swagger::Schemas::Letters,
      Swagger::Schemas::MaintenanceWindows,
      Swagger::Schemas::PhoneNumber,
      Swagger::Schemas::PPIU,
      Swagger::Schemas::SavedForm,
      Swagger::Schemas::States,
      Swagger::Schemas::SubmitDisabilityForm,
      Swagger::Schemas::SubmissionStatus,
      Swagger::Schemas::SuggestedConditions,
      Swagger::Schemas::TermsAndConditions,
      Swagger::Schemas::UploadSupportingEvidence,
      Swagger::Schemas::VAFacilities,
      Swagger::Schemas::CCProviders,
      Swagger::Schemas::Vet360::Address,
      Swagger::Schemas::Vet360::Email,
      Swagger::Schemas::Vet360::Telephone,
      Swagger::Schemas::Vet360::ContactInformation,
      Swagger::Schemas::Vet360::Countries,
      Swagger::Schemas::Vet360::States,
      Swagger::Schemas::Vet360::Zipcodes,
      self
    ].freeze

    def index
      render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
    end
  end
end
