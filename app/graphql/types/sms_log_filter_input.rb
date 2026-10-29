module Types
  class SmsLogFilterInput < PaginatedFilterInput
    description "Filters and paging for the SMS log list"

    argument :search, String, required: false, description: "Matches phone number or message text"
    argument :status, SmsLogStatusEnum, required: false, description: "Only messages with this status"
    argument :message_type, SmsMessageTypeEnum, required: false, description: "Only messages of this type"
    argument :start_date, GraphQL::Types::ISO8601Date, required: false,
                                                       description: "Created on or after this day (YYYY-MM-DD)"
    argument :end_date, GraphQL::Types::ISO8601Date, required: false,
                                                     description: "Created on or before this day (YYYY-MM-DD)"
  end
end
