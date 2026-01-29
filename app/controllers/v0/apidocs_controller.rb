# frozen_string_literal: true

module V0
  class ApidocsController < ApplicationController
    include Swagger::Blocks
    service_tag 'platform-base'

    skip_before_action :authenticate

    swagger_root do
      key :swagger, '2.0'
      info do
        key :version, '1.0.0'
        key :title, 'va.gov API'
        key :description, 'The API for managing va.gov'
        key :termsOfService, ''
        contact do
          key :name, 'va.gov team'
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
        key :name, 'secure_messaging'
        key :description, 'Send and receive secure messages to health providers'
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
        key :name, 'claim_status_tool'
        key :description, 'Claim Status Tool'
      end
      tag do
        key :name, 'site'
        key :description, 'Site service availability and feedback'
      end
      tag do
        key :name, 'medical_copays'
        key :description, 'Veteran Medical Copay information for VA facilities'
      end
      tag do
        key :name, 'banners'
        key :description, 'VAMC Situation Update Banners'
      end
      tag do
        key :name, 'digital_disputes'
        key :description, 'Submit digital dispute PDFs to the Debt Management Center and VBS'
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
      Swagger::Requests::Appeals::Appeals,
      Swagger::Requests::ContactUs::Inquiries,
      Swagger::Requests::BackendStatuses,
      Swagger::Requests::Banners,
      Swagger::Requests::BenefitsClaims,
      Swagger::Requests::DatadogAction,
      Swagger::Requests::BurialClaims,
      Swagger::Requests::BenefitsReferenceData,
      Swagger::Requests::ClaimDocuments,
      Swagger::Requests::ClaimStatus,
      Swagger::Requests::ClaimLetters,
      Swagger::Requests::Coe,
      Swagger::Requests::Debts,
      Swagger::Requests::DebtLetters,
      Swagger::Requests::DependentsApplications,
      Swagger::Requests::DigitalDisputes,
      Swagger::Requests::DependentsVerifications,
      Swagger::Requests::DisabilityCompensationForm,
      Swagger::Requests::DisabilityCompensationInProgressForms,
      Swagger::Requests::EducationBenefitsClaims,
      Swagger::Requests::Efolder,
      Swagger::Requests::EventBusGateway,
      Swagger::Requests::FeatureToggles,
      Swagger::Requests::FinancialStatusReports,
      Swagger::Requests::Form1010cg::Attachments,
      Swagger::Requests::Form1010EzrAttachments,
      Swagger::Requests::Form1010Ezrs,
      Swagger::Requests::Form1095Bs,
      Swagger::Requests::Form210779,
      Swagger::Requests::Form212680,
      Swagger::Requests::Forms,
      Swagger::Requests::Gibct::CalculatorConstants,
      Swagger::Requests::Gibct::Institutions,
      Swagger::Requests::Gibct::InstitutionPrograms,
      Swagger::Requests::Gibct::YellowRibbonPrograms,
      Swagger::Requests::HealthCareApplications,
      Swagger::Requests::HCAAttachments,
      Swagger::Requests::InProgressForms,
      Swagger::Requests::IntentToFile,
      Swagger::Requests::MaintenanceWindows,
      Swagger::Requests::MDOT::Supplies,
      Swagger::Requests::MedicalCopays,
      Swagger::Requests::MviUsers,
      Swagger::Requests::OnsiteNotifications,
      Swagger::Requests::MyVA::SubmissionStatuses,
      Swagger::Requests::IncomeAndAssetsClaims,
      Swagger::Requests::PensionClaims,
      Swagger::Requests::PreneedsClaims,
      Swagger::Requests::Profile,
      Swagger::Requests::Search,
      Swagger::Requests::SearchClickTracking,
      Swagger::Requests::SignIn,
      Swagger::Requests::TravelPay,
      Swagger::Requests::UploadSupportingEvidence,
      Swagger::Requests::User,
      Swagger::Requests::CaregiversAssistanceClaims,
      Swagger::Requests::EducationCareerCounselingClaims,
      Swagger::Requests::VeteranReadinessEmploymentClaims,
      Swagger::Requests::VeteranStatusCards,
      Swagger::Responses::AuthenticationError,
      Swagger::Responses::ForbiddenError,
      Swagger::Responses::RecordNotFoundError,
      Swagger::Responses::SavedForm,
      Swagger::Responses::UnprocessableEntityError,
      Swagger::Schemas::Address,
      Swagger::Schemas::Appeals::Requests,
      Swagger::Schemas::Appeals::NoticeOfDisagreement,
      Swagger::Schemas::ContactUs::SuccessfulInquiryCreation,
      Swagger::Schemas::ContactUs::InquiriesList,
      Swagger::Schemas::AsyncTransaction::Vet360,
      Swagger::Schemas::BenefitsClaims,
      Swagger::Schemas::Countries,
      Swagger::Schemas::ConnectedApplications,
      Swagger::Schemas::Contacts,
      Swagger::Schemas::Dependents,
      Swagger::Schemas::DependentsVerifications,
      Swagger::Schemas::Email,
      Swagger::Schemas::Errors,
      Swagger::Schemas::EVSSAuthError,
      Swagger::Schemas::FinancialStatusReports,
      Swagger::Schemas::Form526::Address,
      Swagger::Schemas::Form526::DateRange,
      Swagger::Schemas::Form526::Disability,
      Swagger::Schemas::Form526::Form0781,
      Swagger::Schemas::Form526::Form4142,
      Swagger::Schemas::Form526::Form526SubmitV2,
      Swagger::Schemas::Form526::Form8940,
      Swagger::Schemas::Form526::SeparationLocations,
      Swagger::Schemas::Form526::JobStatus,
      Swagger::Schemas::Form526::RatedDisabilities,
      Swagger::Schemas::Form526::SubmitDisabilityForm,
      Swagger::Schemas::Form526::SuggestedConditions,
      Swagger::Schemas::Form526::RatingInfo,
      Swagger::Schemas::Forms,
      Swagger::Schemas::Gibct::CalculatorConstants,
      Swagger::Schemas::Gibct::Institutions,
      Swagger::Schemas::Gibct::InstitutionPrograms,
      Swagger::Schemas::Gibct::YellowRibbonPrograms,
      Swagger::Schemas::Gibct::Meta,
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
      Swagger::Schemas::OnsiteNotifications,
      Swagger::Schemas::PhoneNumber,
      Swagger::Schemas::SavedForm,
      Swagger::Schemas::SignIn,
      Swagger::Schemas::States,
      Swagger::Schemas::TravelPay,
      Swagger::Schemas::UploadSupportingEvidence,
      Swagger::Schemas::UserInternalServices,
      Swagger::Schemas::Permission,
      Swagger::Schemas::ValidVAFileNumber,
      Swagger::Schemas::PaymentHistory,
      Swagger::Schemas::Vet360::Address,
      Swagger::Schemas::Vet360::Email,
      Swagger::Schemas::Vet360::Telephone,
      Swagger::Schemas::Vet360::Permission,
      Swagger::Schemas::Vet360::PreferredName,
      Swagger::Schemas::Vet360::GenderIdentity,
      Swagger::Schemas::Vet360::ContactInformation,
      Swagger::Schemas::Vet360::Countries,
      Swagger::Schemas::Vet360::States,
      Swagger::Schemas::Vet360::Zipcodes,
      Swagger::Schemas::Vet360::SchedulingPreferences,
      FacilitiesApi::V2::Schemas::Facilities,
      self
    ].freeze

    def index
      render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
    end
  end
end
