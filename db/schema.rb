# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_09_10_063001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_log_entries", force: :cascade do |t|
    t.bigint "run_id", null: false
    t.string "action_taken", null: false
    t.string "target_element"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id"], name: "index_audit_log_entries_on_run_id"
  end

  create_table "findings", force: :cascade do |t|
    t.bigint "run_id", null: false
    t.string "title", null: false
    t.jsonb "repro_steps", default: [], null: false
    t.integer "severity", null: false
    t.string "clickup_task_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id", "title"], name: "index_findings_on_run_id_and_title", unique: true
    t.index ["run_id"], name: "index_findings_on_run_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.integer "integration_type", null: false
    t.string "scope"
    t.string "external_account_id"
    t.datetime "connected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "repo_full_name"
    t.index ["project_id", "integration_type"], name: "index_integrations_on_project_id_and_integration_type", unique: true
    t.index ["project_id"], name: "index_integrations_on_project_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "project_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_memberships_on_project_id"
    t.index ["user_id", "project_id"], name: "index_memberships_on_user_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "target_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "repo_connection_id"
    t.index ["repo_connection_id"], name: "index_projects_on_repo_connection_id"
  end

  create_table "role_credentials", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "role_name", null: false
    t.string "encrypted_credential_ref", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "role_name"], name: "index_role_credentials_on_project_id_and_role_name", unique: true
    t.index ["project_id"], name: "index_role_credentials_on_project_id"
  end

  create_table "runs", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "scope_feature_id", null: false
    t.string "role_name", null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_runs_on_project_id"
    t.index ["scope_feature_id"], name: "index_runs_on_scope_feature_id"
  end

  create_table "scope_features", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "route"
    t.string "source"
    t.boolean "approved", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_scope_features_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_scope_features_on_project_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_log_entries", "runs"
  add_foreign_key "findings", "runs"
  add_foreign_key "integrations", "projects"
  add_foreign_key "memberships", "projects"
  add_foreign_key "memberships", "users"
  add_foreign_key "projects", "integrations", column: "repo_connection_id"
  add_foreign_key "role_credentials", "projects"
  add_foreign_key "runs", "projects"
  add_foreign_key "runs", "scope_features"
  add_foreign_key "scope_features", "projects"
end
