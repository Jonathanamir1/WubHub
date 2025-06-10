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

ActiveRecord::Schema[7.1].define(version: 2025_06_10_092829) do
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

  create_table "containers", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.bigint "parent_container_id"
    t.string "name", null: false
    t.string "container_type", null: false
    t.integer "template_level", null: false
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["container_type", "template_level"], name: "index_containers_on_container_type_and_template_level"
    t.index ["parent_container_id"], name: "index_containers_on_parent_container_id"
    t.index ["workspace_id"], name: "index_containers_on_workspace_id"
  end

  create_table "file_attachments", force: :cascade do |t|
    t.string "filename"
    t.string "attachable_type", null: false
    t.bigint "attachable_id", null: false
    t.bigint "file_size"
    t.string "content_type"
    t.jsonb "metadata"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id"], name: "index_file_attachments_on_attachable"
    t.index ["user_id"], name: "index_file_attachments_on_user_id"
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

  create_table "track_contents", force: :cascade do |t|
    t.bigint "container_id", null: false
    t.bigint "user_id", null: false
    t.string "title"
    t.text "description"
    t.string "content_type"
    t.text "text_content"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tags", default: [], array: true
    t.index ["container_id"], name: "index_track_contents_on_container_id"
    t.index ["tags"], name: "index_track_contents_on_tags", using: :gin
    t.index ["user_id"], name: "index_track_contents_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "username"
    t.string "name"
    t.text "bio"
    t.string "password_digest"
    t.string "profile_image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_workspaces_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "containers", "containers", column: "parent_container_id"
  add_foreign_key "containers", "workspaces"
  add_foreign_key "file_attachments", "users"
  add_foreign_key "privacies", "users"
  add_foreign_key "roles", "users"
  add_foreign_key "track_contents", "containers"
  add_foreign_key "track_contents", "users"
  add_foreign_key "workspaces", "users"
end
