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

ActiveRecord::Schema[7.1].define(version: 2025_07_17_164446) do
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

  create_table "assets", force: :cascade do |t|
    t.string "filename", null: false
    t.text "path"
    t.bigint "file_size"
    t.string "content_type"
    t.jsonb "metadata", default: {}
    t.bigint "workspace_id", null: false
    t.bigint "container_id"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["container_id"], name: "index_assets_on_container_id"
    t.index ["content_type"], name: "index_assets_on_content_type"
    t.index ["created_at"], name: "index_assets_on_created_at"
    t.index ["path"], name: "index_assets_on_path"
    t.index ["user_id"], name: "index_assets_on_user_id"
    t.index ["workspace_id", "container_id", "filename"], name: "index_assets_on_workspace_container_filename", unique: true
    t.index ["workspace_id", "path"], name: "index_assets_on_workspace_id_and_path"
    t.index ["workspace_id"], name: "index_assets_on_workspace_id"
  end

  create_table "chunks", force: :cascade do |t|
    t.bigint "upload_session_id", null: false
    t.integer "chunk_number", null: false
    t.bigint "size", null: false
    t.string "checksum"
    t.string "status", default: "pending", null: false
    t.text "storage_key"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checksum"], name: "index_chunks_on_checksum"
    t.index ["created_at"], name: "index_chunks_on_created_at"
    t.index ["status"], name: "index_chunks_on_status"
    t.index ["upload_session_id", "chunk_number"], name: "index_chunks_on_upload_session_id_and_chunk_number", unique: true
    t.index ["upload_session_id", "status"], name: "index_chunks_on_upload_session_id_and_status"
    t.index ["upload_session_id"], name: "index_chunks_on_upload_session_id"
  end

  create_table "containers", force: :cascade do |t|
    t.string "name", null: false
    t.text "path"
    t.bigint "workspace_id", null: false
    t.bigint "parent_container_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_container_id"], name: "index_containers_on_parent_container_id"
    t.index ["path"], name: "index_containers_on_path"
    t.index ["workspace_id", "parent_container_id", "name"], name: "index_containers_on_workspace_parent_name", unique: true
    t.index ["workspace_id", "path"], name: "index_containers_on_workspace_id_and_path"
    t.index ["workspace_id"], name: "index_containers_on_workspace_id"
  end

  create_table "privacies", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "privatable_type", null: false
    t.bigint "privatable_id", null: false
    t.string "level", default: "inherited", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["privatable_type", "privatable_id"], name: "index_privacies_on_privatable"
    t.index ["privatable_type", "privatable_id"], name: "index_privacies_on_privatable_type_and_privatable_id", unique: true
    t.index ["user_id"], name: "index_privacies_on_user_id"
  end

  create_table "queue_items", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "user_id", null: false
    t.string "batch_id", null: false
    t.integer "draggable_type", default: 1, null: false
    t.string "draggable_name", null: false
    t.text "original_path"
    t.integer "total_files", default: 0, null: false
    t.integer "completed_files", default: 0, null: false
    t.integer "failed_files", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id", "status"], name: "index_queue_items_on_batch_id_and_status"
    t.index ["batch_id"], name: "index_queue_items_on_batch_id"
    t.index ["created_at"], name: "index_queue_items_on_created_at"
    t.index ["metadata"], name: "index_queue_items_on_metadata", using: :gin
    t.index ["user_id", "status"], name: "index_queue_items_on_user_id_and_status"
    t.index ["user_id"], name: "index_queue_items_on_user_id"
    t.index ["workspace_id", "status"], name: "index_queue_items_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_queue_items_on_workspace_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "roleable_id"
    t.string "roleable_type"
    t.index ["roleable_type", "roleable_id"], name: "index_roles_on_roleable"
    t.index ["user_id"], name: "index_roles_on_user_id"
  end

  create_table "upload_sessions", force: :cascade do |t|
    t.string "filename", limit: 255, null: false
    t.bigint "total_size", null: false
    t.integer "chunks_count", null: false
    t.bigint "workspace_id", null: false
    t.bigint "container_id"
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "assembled_file_path"
    t.datetime "virus_scan_queued_at"
    t.datetime "virus_scan_completed_at"
    t.bigint "queue_item_id"
    t.index ["assembled_file_path"], name: "index_upload_sessions_on_assembled_file_path"
    t.index ["container_id"], name: "index_upload_sessions_on_container_id"
    t.index ["created_at"], name: "index_upload_sessions_on_created_at"
    t.index ["queue_item_id", "status"], name: "index_upload_sessions_on_queue_item_id_and_status"
    t.index ["queue_item_id"], name: "index_upload_sessions_on_queue_item_id"
    t.index ["status", "created_at"], name: "index_upload_sessions_on_status_and_created_at"
    t.index ["status"], name: "index_upload_sessions_on_status"
    t.index ["user_id", "status"], name: "index_upload_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_upload_sessions_on_user_id"
    t.index ["virus_scan_completed_at"], name: "index_upload_sessions_on_virus_scan_completed_at"
    t.index ["virus_scan_queued_at"], name: "index_upload_sessions_on_virus_scan_queued_at"
    t.index ["workspace_id", "container_id", "filename"], name: "index_upload_sessions_unique_filename_per_location", unique: true, where: "((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('uploading'::character varying)::text, ('assembling'::character varying)::text]))"
    t.index ["workspace_id", "status"], name: "index_upload_sessions_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_upload_sessions_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.text "bio"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "onboarding_completed_at"
    t.string "onboarding_step", default: "not_started"
    t.string "name", null: false
    t.string "google_id"
    t.text "onboarding_data"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_id"], name: "index_users_on_google_id", unique: true
    t.index ["onboarding_completed_at"], name: "index_users_on_onboarding_completed_at"
    t.index ["onboarding_step"], name: "index_users_on_onboarding_step"
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "workspace_type"
    t.string "visibility"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_workspaces_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assets", "containers"
  add_foreign_key "assets", "users"
  add_foreign_key "assets", "workspaces"
  add_foreign_key "chunks", "upload_sessions"
  add_foreign_key "containers", "containers", column: "parent_container_id"
  add_foreign_key "containers", "workspaces"
  add_foreign_key "privacies", "users"
  add_foreign_key "queue_items", "users"
  add_foreign_key "queue_items", "workspaces"
  add_foreign_key "roles", "users"
  add_foreign_key "upload_sessions", "containers"
  add_foreign_key "upload_sessions", "queue_items"
  add_foreign_key "upload_sessions", "users"
  add_foreign_key "upload_sessions", "workspaces"
  add_foreign_key "workspaces", "users"
end
