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

ActiveRecord::Schema[8.1].define(version: 2026_10_23_062005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

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

  create_table "email_logs", force: :cascade do |t|
    t.string "recipient", null: false
    t.string "mailer", null: false
    t.string "mailer_method", null: false
    t.string "subject"
    t.text "body"
    t.integer "status", null: false
    t.text "error_message"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "search_document", type: :text, as: "(((recipient)::text || ' '::text) || (COALESCE(subject, ''::character varying))::text)", stored: true
    t.string "delivery_id", null: false
    t.integer "attempts", default: 1, null: false
    t.index ["created_at", "id"], name: "index_email_logs_on_created_at_and_id"
    t.index ["delivery_id"], name: "index_email_logs_on_delivery_id", unique: true
    t.index ["search_document"], name: "index_email_logs_on_search_document", opclass: :gin_trgm_ops, using: :gin
    t.index ["status", "created_at", "id"], name: "index_email_logs_on_status_and_created_at_and_id"
  end

  create_table "one_time_passwords", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "purpose", null: false
    t.string "code_digest", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_one_time_passwords_on_expires_at"
    t.index ["user_id", "purpose"], name: "index_one_time_passwords_on_user_id_and_purpose", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "impersonator_id"
    t.string "token_digest", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "expires_at", null: false
    t.datetime "last_active_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["impersonator_id"], name: "index_sessions_on_impersonator_id"
    t.index ["last_active_at"], name: "index_sessions_on_last_active_at"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sms_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "recipient", null: false
    t.text "body", null: false
    t.integer "message_type", null: false
    t.integer "status", default: 0, null: false
    t.string "provider_sid"
    t.string "error_code"
    t.text "error_message"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "search_document", type: :text, as: "(((recipient)::text || ' '::text) || body)", stored: true
    t.index ["created_at", "id"], name: "index_sms_logs_on_created_at_and_id"
    t.index ["message_type", "created_at", "id"], name: "index_sms_logs_on_message_type_and_created_at_and_id"
    t.index ["search_document"], name: "index_sms_logs_on_search_document", opclass: :gin_trgm_ops, using: :gin
    t.index ["status", "created_at", "id"], name: "index_sms_logs_on_status_and_created_at_and_id"
    t.index ["user_id"], name: "index_sms_logs_on_user_id"
    t.index ["user_id"], name: "index_sms_logs_one_welcome_per_user", unique: true, where: "(message_type = 0)"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "unconfirmed_email"
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.string "first_name"
    t.string "last_name"
    t.bigint "invited_by_id"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.datetime "archived_at"
    t.datetime "access_revoked_at"
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.virtual "search_document", type: :text, as: "(((((email)::text || ' '::text) || (COALESCE(first_name, ''::character varying))::text) || ' '::text) || (COALESCE(last_name, ''::character varying))::text)", stored: true
    t.string "phone"
    t.string "google_uid"
    t.datetime "email_verified_at"
    t.index ["created_at", "id"], name: "index_users_on_created_at_and_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true, where: "(google_uid IS NOT NULL)"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["role", "created_at", "id"], name: "index_users_on_role_and_created_at_and_id"
    t.index ["search_document"], name: "index_users_on_search_document", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.jsonb "object"
    t.jsonb "object_changes"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "one_time_passwords", "users", on_delete: :cascade
  add_foreign_key "sessions", "users", column: "impersonator_id", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "sms_logs", "users", on_delete: :nullify
  add_foreign_key "users", "users", column: "invited_by_id", on_delete: :nullify
end
