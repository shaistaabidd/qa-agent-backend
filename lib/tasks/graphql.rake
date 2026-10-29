require "graphql/rake_task"

# bin/rails graphql:schema:idl writes schema.graphql for frontend codegen and review diffs.
GraphQL::RakeTask.new(schema_name: "QaAgentBackendSchema", directory: Rails.root.to_s, idl_outfile: "schema.graphql")
