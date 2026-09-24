module Types
  module Shared
    class StatusPayload < Types::BaseObject
      field :success, Boolean, null: false
      field :message, String, null: true
    end
  end
end
