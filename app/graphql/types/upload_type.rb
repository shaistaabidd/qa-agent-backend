module Types
  # Multipart upload (graphql-multipart-request spec). Unwraps the gem's
  # delegator so ActiveStorage receives a real ActionDispatch::Http::UploadedFile.
  class UploadType < ApolloUploadServer::Upload
    description "A file sent with a multipart GraphQL request"

    def self.coerce_input(value, context)
      super&.__getobj__
    end
  end
end
