class PPMS::ServiceSerializer
  include FastJsonapi::ObjectSerializer

  set_id :specialty_code

  attributes :classification,
              :grouping,
              :specialization,
              :specialty_code,
              :specialty_description
end