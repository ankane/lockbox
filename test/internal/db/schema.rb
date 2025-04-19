ActiveRecord::Schema.define do
  create_table :action_text_rich_texts do |t|
    t.string     :name, null: false
    t.text       :body_ciphertext
    t.references :record, null: false, polymorphic: true, index: false

    t.timestamps

    t.index [ :record_type, :record_id, :name ], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table :active_storage_blobs do |t|
    t.string   :key,        null: false
    t.string   :filename,   null: false
    t.string   :content_type
    t.text     :metadata
    t.bigint   :byte_size,  null: false
    t.string   :checksum,   null: false
    t.datetime :created_at, null: false
    t.string   :service_name

    t.index [ :key ], unique: true
  end

  create_table :active_storage_attachments do |t|
    t.string     :name,     null: false
    t.references :record,   null: false, polymorphic: true, index: false
    t.references :blob,     null: false

    t.datetime :created_at, null: false

    t.index [ :record_type, :record_id, :name, :blob_id ], name: "index_active_storage_attachments_uniqueness", unique: true
    t.foreign_key :active_storage_blobs, column: :blob_id
  end

  create_table :active_storage_variant_records do |t|
    t.belongs_to :blob, null: false, index: false
    t.string :variation_digest, null: false

    t.index %i[ blob_id variation_digest ], name: "index_active_storage_variant_records_uniqueness", unique: true
    t.foreign_key :active_storage_blobs, column: :blob_id
  end

  create_table :users do |t|
    t.string :name
    t.string :document
    t.string :documents
    t.text :email_ciphertext
    t.text :phone_ciphertext
    t.text :properties
    t.text :properties2_ciphertext
    t.text :settings
    t.text :settings2_ciphertext
    t.text :messages
    t.text :messages2_ciphertext
    t.string :country
    t.text :country2_ciphertext
    t.boolean :active
    t.text :active2_ciphertext
    t.date :born_on
    t.text :born_on2_ciphertext
    t.datetime :signed_at
    t.text :signed_at2_ciphertext
    t.time :opens_at
    t.text :opens_at2_ciphertext
    t.bigint :sign_in_count
    t.text :sign_in_count2_ciphertext
    t.float :latitude
    t.text :latitude2_ciphertext
    if ["mysql2", "trilogy"].include?(ENV["ADAPTER"])
      t.decimal :longitude, precision: 65, scale: 30
    else
      t.decimal :longitude
    end
    t.text :longitude2_ciphertext
    t.binary :video
    t.text :video2_ciphertext
    t.column :data, :json
    t.text :data2_ciphertext
    t.text :info
    t.text :info2_ciphertext
    t.text :credentials
    t.text :credentials2_ciphertext
    t.text :credentials3
    t.text :configuration
    t.text :configuration2_ciphertext
    t.text :coordinates
    t.text :coordinates2_ciphertext

    if ENV["ADAPTER"] == "postgresql"
      t.inet :ip
      t.text :ip2_ciphertext
    end

    t.text :config
    t.text :config2_ciphertext
    t.text :conf_ciphertext
    t.text :city_ciphertext
    t.binary :ssn_ciphertext
    t.text :region_ciphertext
    t.text :state
    t.text :state_ciphertext
    t.text :photo_data
  end

  create_table :posts do |t|
    t.text :title_ciphertext
  end

  create_table :robots do |t|
    t.text :name
    t.text :email
    t.text :properties
    t.text :name_ciphertext
    t.text :email_ciphertext
    t.text :properties_ciphertext
  end

  create_table :comments do |t|
  end

  create_table :admins do |t|
    t.text :name
    t.text :email_ciphertext
    t.text :personal_email_ciphertext
    t.text :other_email_ciphertext
    t.text :email_address_ciphertext
    t.text :encrypted_email
  end

  create_table :agents do |t|
    t.text :name
    t.text :email_ciphertext
    t.text :personal_email_ciphertext
  end

  create_table :people do |t|
    t.text :data_ciphertext
  end
end
