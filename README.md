# Lockbox

:package: Modern encryption for Ruby and Rails

- Works with database fields, files, and strings
- Maximizes compatibility with existing code and libraries
- Makes migrating existing data and key rotation easy
- Has zero dependencies and many integrations

Learn [the principles behind it](https://ankane.org/modern-encryption-rails), [how to secure emails with Devise](https://ankane.org/securing-user-emails-lockbox), and [how to secure sensitive data in Rails](https://ankane.org/sensitive-data-rails).

[![Build Status](https://github.com/ankane/lockbox/actions/workflows/build.yml/badge.svg)](https://github.com/ankane/lockbox/actions)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem "lockbox"
```

## Key Generation

Generate a key

```ruby
Lockbox.generate_key
```

Store the key with your other secrets. This is typically Rails credentials or an environment variable ([dotenv](https://github.com/bkeepers/dotenv) is great for this). Be sure to use different keys in development and production.

Set the following environment variable with your key (you can use this one in development)

```sh
LOCKBOX_MASTER_KEY=0000000000000000000000000000000000000000000000000000000000000000
```

or add it to your credentials for each environment (`rails credentials:edit --environment <env>`)

```yml
lockbox:
  master_key: "0000000000000000000000000000000000000000000000000000000000000000"
```

or create `config/initializers/lockbox.rb` with something like

```ruby
Lockbox.master_key = Rails.application.credentials.lockbox[:master_key]
```

Then follow the instructions below for the data you want to encrypt.

#### Database Fields

- [Active Record](#active-record)
- [Action Text](#action-text)
- [Mongoid](#mongoid)

#### Files

- [Active Storage](#active-storage)
- [CarrierWave](#carrierwave)
- [Shrine](#shrine)
- [Local Files](#local-files)

#### Other

- [Strings](#strings)

## Active Record

Create a migration with:

```ruby
class AddEmailCiphertextToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_ciphertext, :text
  end
end
```

Add to your model:

```ruby
class User < ApplicationRecord
  has_encrypted :email
end
```

You can use `email` just like any other attribute.

```ruby
User.create!(email: "hi@example.org")
```

If you need to query encrypted fields, check out [Blind Index](https://github.com/ankane/blind_index).

#### Multiple Fields

You can specify multiple fields in single line.

```ruby
class User < ApplicationRecord
  has_encrypted :email, :phone, :city
end
```

#### Types

Fields are strings by default. Specify the type of a field with:

```ruby
class User < ApplicationRecord
  has_encrypted :birthday, type: :date
  has_encrypted :signed_at, type: :datetime
  has_encrypted :opens_at, type: :time
  has_encrypted :active, type: :boolean
  has_encrypted :salary, type: :integer
  has_encrypted :latitude, type: :float
  has_encrypted :longitude, type: :decimal
  has_encrypted :video, type: :binary
  has_encrypted :properties, type: :json
  has_encrypted :settings, type: :hash
  has_encrypted :messages, type: :array
  has_encrypted :ip, type: :inet
end
```

**Note:** Use a `text` column for the ciphertext in migrations, regardless of the type

Lockbox automatically works with serialized fields for maximum compatibility with existing code and libraries.

```ruby
class User < ApplicationRecord
  serialize :properties, JSON
  store :settings, accessors: [:color, :homepage]
  attribute :configuration, CustomType.new

  has_encrypted :properties, :settings, :configuration
end
```

For [Active Record Store](https://api.rubyonrails.org/classes/ActiveRecord/Store.html), encrypt the column rather than individual accessors.

For [StoreModel](https://github.com/DmitryTsepelev/store_model), use:

```ruby
class User < ApplicationRecord
  has_encrypted :configuration, type: Configuration.to_type

  after_initialize do
    self.configuration ||= {}
  end
end
```

#### Validations

Validations work as expected with the exception of uniqueness. Uniqueness validations require a [blind index](https://github.com/ankane/blind_index).

#### Fixtures

You can use encrypted attributes in fixtures with:

```yml
test_user:
  email_ciphertext: <%= User.generate_email_ciphertext("secret").inspect %>
```

Be sure to include the `inspect` at the end or it won’t be encoded properly in YAML.

#### Migrating Existing Data

Lockbox makes it easy to encrypt an existing column without downtime.

Add a new column for the ciphertext, then add to your model:

```ruby
class User < ApplicationRecord
  has_encrypted :email, migrating: true
end
```

Backfill the data in the Rails console:

```ruby
Lockbox.migrate(User)
```

Then update the model to the desired state:

```ruby
class User < ApplicationRecord
  has_encrypted :email

  # remove this line after dropping email column
  self.ignored_columns += ["email"]
end
```

Finally, drop the unencrypted column.

If adding blind indexes, mark them as `migrating` during this process as well.

```ruby
class User < ApplicationRecord
  blind_index :email, migrating: true
end
```

#### Model Changes

If tracking changes to model attributes, be sure to remove or redact encrypted attributes.

PaperTrail

```ruby
class User < ApplicationRecord
  # for an encrypted history (still tracks ciphertext changes)
  has_paper_trail skip: [:email]

  # for no history (add blind indexes as well)
  has_paper_trail skip: [:email, :email_ciphertext]
end
```

Audited

```ruby
class User < ApplicationRecord
  # for an encrypted history (still tracks ciphertext changes)
  audited except: [:email]

  # for no history (add blind indexes as well)
  audited except: [:email, :email_ciphertext]
end
```

#### Decryption

To decrypt data outside the model, use:

```ruby
User.decrypt_email_ciphertext(user.email_ciphertext)
```

## Action Text

**Note:** Action Text uses direct uploads for files, which cannot be encrypted with application-level encryption like Lockbox. This only encrypts the database field.

Create a migration with:

```ruby
class AddBodyCiphertextToRichTexts < ActiveRecord::Migration[8.0]
  def change
    add_column :action_text_rich_texts, :body_ciphertext, :text
  end
end
```

Create `config/initializers/lockbox.rb` with:

```ruby
Lockbox.encrypts_action_text_body(migrating: true)
```

Migrate existing data:

```ruby
Lockbox.migrate(ActionText::RichText)
```

Update the initializer:

```ruby
Lockbox.encrypts_action_text_body
```

And drop the unencrypted column.

#### Options

You can pass any Lockbox options to the `encrypts_action_text_body` method.

## Mongoid

Add to your model:

```ruby
class User
  field :email_ciphertext, type: String

  has_encrypted :email
end
```

You can use `email` just like any other attribute.

```ruby
User.create!(email: "hi@example.org")
```

If you need to query encrypted fields, check out [Blind Index](https://github.com/ankane/blind_index).

You can [migrate existing data](#migrating-existing-data) similarly to Active Record.

## Active Storage

Add to your model:

```ruby
class User < ApplicationRecord
  has_one_attached :license
  encrypts_attached :license
end
```

Works with multiple attachments as well.

```ruby
class User < ApplicationRecord
  has_many_attached :documents
  encrypts_attached :documents
end
```

There are a few limitations to be aware of:

- Variants and previews aren’t supported when encrypted
- Metadata like image width and height aren’t extracted when encrypted
- Direct uploads can’t be encrypted with application-level encryption like Lockbox, but can use server-side encryption

To serve encrypted files, use a controller action.

```ruby
def license
  user = User.find(params[:id])
  send_data user.license.download, type: user.license.content_type
end
```

Use `filename` to specify a filename or `disposition: "inline"` to show inline.

#### Migrating Existing Files

Lockbox makes it easy to encrypt existing files without downtime.

Add to your model:

```ruby
class User < ApplicationRecord
  encrypts_attached :license, migrating: true
end
```

Migrate existing files:

```ruby
Lockbox.migrate(User)
```

Then update the model to the desired state:

```ruby
class User < ApplicationRecord
  encrypts_attached :license
end
```

## CarrierWave

Add to your uploader:

```ruby
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt
end
```

Encryption is applied to all versions after processing.

You can mount the uploader [as normal](https://github.com/carrierwaveuploader/carrierwave#activerecord). With Active Record, this involves creating a migration:

```ruby
class AddLicenseToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :license, :string
  end
end
```

And updating the model:

```ruby
class User < ApplicationRecord
  mount_uploader :license, LicenseUploader
end
```

To serve encrypted files, use a controller action.

```ruby
def license
  user = User.find(params[:id])
  send_data user.license.read, type: user.license.content_type
end
```

Use `filename` to specify a filename or `disposition: "inline"` to show inline.

#### Migrating Existing Files

Encrypt existing files without downtime. Create a new encrypted uploader:

```ruby
class LicenseV2Uploader < CarrierWave::Uploader::Base
  encrypt key: Lockbox.attribute_key(table: "users", attribute: "license")
end
```

Add a new column for the uploader, then add to your model:

```ruby
class User < ApplicationRecord
  mount_uploader :license_v2, LicenseV2Uploader

  before_save :migrate_license, if: :license_changed?

  def migrate_license
    self.license_v2 = license
  end
end
```

Migrate existing files:

```ruby
User.find_each do |user|
  if user.license? && !user.license_v2?
    user.migrate_license
    user.save!
  end
end
```

Then update the model to the desired state:

```ruby
class User < ApplicationRecord
  mount_uploader :license, LicenseV2Uploader, mount_on: :license_v2
end
```

Finally, delete the unencrypted files and drop the column for the original uploader. You can also remove the `key` option from the uploader.

## Shrine

#### Models

Include the attachment as normal:

```ruby
class User < ApplicationRecord
  include LicenseUploader::Attachment(:license)
end
```

And encrypt in a controller (or background job, etc) with:

```ruby
license = params.require(:user).fetch(:license)
lockbox = Lockbox.new(key: Lockbox.attribute_key(table: "users", attribute: "license"))
user.license = lockbox.encrypt_io(license)
```

To serve encrypted files, use a controller action.

```ruby
def license
  user = User.find(params[:id])
  lockbox = Lockbox.new(key: Lockbox.attribute_key(table: "users", attribute: "license"))
  send_data lockbox.decrypt(user.license.read), type: user.license.mime_type
end
```

Use `filename` to specify a filename or `disposition: "inline"` to show inline.

#### Non-Models

Generate a key

```ruby
key = Lockbox.generate_key
```

Create a lockbox

```ruby
lockbox = Lockbox.new(key: key)
```

Encrypt files before passing them to Shrine

```ruby
LicenseUploader.upload(lockbox.encrypt_io(file), :store)
```

And decrypt them after reading

```ruby
lockbox.decrypt(uploaded_file.read)
```

## Local Files

Generate a key

```ruby
key = Lockbox.generate_key
```

Create a lockbox

```ruby
lockbox = Lockbox.new(key: key)
```

Encrypt

```ruby
ciphertext = lockbox.encrypt(File.binread("file.txt"))
```

Decrypt

```ruby
lockbox.decrypt(ciphertext)
```

## Strings

Generate a key

```ruby
key = Lockbox.generate_key
```

Create a lockbox

```ruby
lockbox = Lockbox.new(key: key, encode: true)
```

Encrypt

```ruby
ciphertext = lockbox.encrypt("hello")
```

Decrypt

```ruby
lockbox.decrypt(ciphertext)
```

Use `decrypt_str` get the value as UTF-8

## Key Rotation

To make key rotation easy, you can pass previous versions of keys that can decrypt.

Create `config/initializers/lockbox.rb` with:

```ruby
Lockbox.default_options[:previous_versions] = [{master_key: previous_key}]
```

To rotate existing Active Record & Mongoid records, use:

```ruby
Lockbox.rotate(User, attributes: [:email])
```

To rotate existing Action Text records, use:

```ruby
Lockbox.rotate(ActionText::RichText, attributes: [:body])
```

To rotate existing Active Storage files, use:

```ruby
User.with_attached_license.find_each do |user|
  user.license.rotate_encryption!
end
```

To rotate existing CarrierWave files, use:

```ruby
User.find_each do |user|
  user.license.rotate_encryption!
  # or for multiple files
  user.licenses.map(&:rotate_encryption!)
end
```

Once everything is rotated, you can remove `previous_versions` from the initializer.

### Individual Fields & Files

You can also pass previous versions to individual fields and files.

```ruby
class User < ApplicationRecord
  has_encrypted :email, previous_versions: [{master_key: previous_key}]
end
```

### Local Files & Strings

To rotate local files and strings, use:

```ruby
Lockbox.new(key: key, previous_versions: [{key: previous_key}])
```

## Auditing

It’s a good idea to track user and employee access to sensitive data. Lockbox provides a convenient way to do this with Active Record, but you can use a similar pattern to write audits to any location.

```sh
rails generate lockbox:audits
rails db:migrate
```

Then create an audit wherever a user can view data:

```ruby
class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])

    LockboxAudit.create!(
      subject: @user,
      viewer: current_user,
      data: ["name", "email"],
      context: "#{controller_name}##{action_name}",
      ip: request.remote_ip
    )
  end
end
```

Query audits with:

```ruby
LockboxAudit.last(100)
```

**Note:** This approach is not intended to be used in the event of a breach or insider attack, as it’s trivial for someone with access to your infrastructure to bypass.

## Algorithms

### AES-GCM

This is the default algorithm. It’s:

- well-studied
- NIST recommended
- an IETF standard
- fast thanks to a [dedicated instruction set](https://en.wikipedia.org/wiki/AES_instruction_set)

Lockbox uses 256-bit keys.

**For users who do a lot of encryptions:** You should rotate an individual key after 2 billion encryptions to minimize the chance of a [nonce collision](https://www.cryptologie.net/article/402/is-symmetric-security-solved/), which will expose the authentication key. Each database field and file uploader use a different key (derived from the master key) to extend this window.

### XSalsa20

You can also use XSalsa20, which uses an extended nonce so you don’t have to worry about nonce collisions. First, [install Libsodium](https://github.com/crypto-rb/rbnacl/wiki/Installing-libsodium). It comes preinstalled on [Heroku](https://devcenter.heroku.com/articles/stack-packages). For Homebrew, use:

```sh
brew install libsodium
```

And for Ubuntu, use:

```sh
sudo apt-get install libsodium23
```

Then add to your Gemfile:

```ruby
gem "rbnacl"
```

And add to your model:


```ruby
class User < ApplicationRecord
  has_encrypted :email, algorithm: "xsalsa20"
end
```

Make it the default with:

```ruby
Lockbox.default_options[:algorithm] = "xsalsa20"
```

You can also pass an algorithm to `previous_versions` for key rotation.

## Hybrid Cryptography

[Hybrid cryptography](https://en.wikipedia.org/wiki/Hybrid_cryptosystem) allows servers to encrypt data without being able to decrypt it.

Follow the instructions above for installing Libsodium and including `rbnacl` in your Gemfile.

Generate a key pair with:

```ruby
Lockbox.generate_key_pair
```

Store the keys with your other secrets. Then use:

```ruby
class User < ApplicationRecord
  has_encrypted :email, algorithm: "hybrid", encryption_key: encryption_key, decryption_key: decryption_key
end
```

Make sure `decryption_key` is `nil` on servers that shouldn’t decrypt.

This uses X25519 for key exchange and XSalsa20 for encryption.

## Key Configuration

Lockbox supports a few different ways to set keys for database fields and files.

1. Master key
2. Per field/uploader
3. Per record

### Master Key

By default, the master key is used to generate unique keys for each field/uploader. This technique comes from [CipherSweet](https://ciphersweet.paragonie.com/internals/key-hierarchy). The table name and column/uploader name are both used in this process.

You can get an individual key with:

```ruby
Lockbox.attribute_key(table: "users", attribute: "email_ciphertext")
```

To rename a table with encrypted columns/uploaders, use:

```ruby
class User < ApplicationRecord
  has_encrypted :email, key_table: "original_table"
end
```

To rename an encrypted column itself, use:

```ruby
class User < ApplicationRecord
  has_encrypted :email, key_attribute: "original_column"
end
```

### Per Field/Uploader

To set a key for an individual field/uploader, use a string:

```ruby
class User < ApplicationRecord
  has_encrypted :email, key: ENV["USER_EMAIL_ENCRYPTION_KEY"]
end
```

Or a proc:

```ruby
class User < ApplicationRecord
  has_encrypted :email, key: -> { code }
end
```

### Per Record

To use a different key for each record, use a symbol:

```ruby
class User < ApplicationRecord
  has_encrypted :email, key: :some_method
end
```

Or a proc:

```ruby
class User < ApplicationRecord
  has_encrypted :email, key: -> { some_method }
end
```

## Key Management

You can use a key management service to manage your keys with [KMS Encrypted](https://github.com/ankane/kms_encrypted).

For Active Record and Mongoid, use:

```ruby
class User < ApplicationRecord
  has_encrypted :email, key: :kms_key
end
```

For Action Text, use:

```ruby
ActiveSupport.on_load(:action_text_rich_text) do
  ActionText::RichText.has_kms_key
end

Lockbox.encrypts_action_text_body(key: :kms_key)
```

For Active Storage, use:

```ruby
class User < ApplicationRecord
  encrypts_attached :license, key: :kms_key
end
```

For CarrierWave, use:

```ruby
class LicenseUploader < CarrierWave::Uploader::Base
  encrypt key: -> { model.kms_key }
end
```

**Note:** KMS Encrypted’s key rotation does not know to rotate encrypted files, so avoid calling `record.rotate_kms_key!` on models with file uploads for now.

## Data Leakage

While encryption hides the content of a message, an attacker can still get the length of the message (since the length of the ciphertext is the length of the message plus a constant number of bytes).

Let’s say you want to encrypt the status of a candidate’s background check. Valid statuses are `clear`, `consider`, and `fail`. Even with the data encrypted, it’s trivial to map the ciphertext to a status.

```ruby
lockbox = Lockbox.new(key: key)
lockbox.encrypt("fail").bytesize      # 32
lockbox.encrypt("clear").bytesize     # 33
lockbox.encrypt("consider").bytesize  # 36
```

Add padding to conceal the exact length of messages.

```ruby
lockbox = Lockbox.new(key: key, padding: true)
lockbox.encrypt("fail").bytesize      # 44
lockbox.encrypt("clear").bytesize     # 44
lockbox.encrypt("consider").bytesize  # 44
```

The block size for padding is 16 bytes by default. Lockbox uses [ISO/IEC 7816-4](https://en.wikipedia.org/wiki/Padding_(cryptography)#ISO/IEC_7816-4) padding, which uses at least one byte, so if we have a status larger than 15 bytes, it will have a different length than the others.

```ruby
box.encrypt("length15status!").bytesize   # 44
box.encrypt("length16status!!").bytesize  # 60
```

Change the block size with:

```ruby
Lockbox.new(padding: 32) # bytes
```

## Associated Data

You can pass extra context during encryption to make sure encrypted data isn’t moved to a different context.

```ruby
lockbox = Lockbox.new(key: key)
ciphertext = lockbox.encrypt(message, associated_data: "somecontext")
```

Without the same context, decryption will fail.

```ruby
lockbox.decrypt(ciphertext, associated_data: "somecontext")  # success
lockbox.decrypt(ciphertext, associated_data: "othercontext") # fails
```

You can also use it with database fields and files.

```ruby
class User < ApplicationRecord
  has_encrypted :email, associated_data: -> { code }
end
```

## Binary Columns

You can use `binary` columns for the ciphertext instead of `text` columns.

```ruby
class AddEmailCiphertextToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_ciphertext, :binary
  end
end
```

Disable Base64 encoding to save space.

```ruby
class User < ApplicationRecord
  has_encrypted :email, encode: false
end
```

or set it globally:

```ruby
Lockbox.encode_attributes = false
```

## Compatibility

It’s easy to read encrypted data in another language if needed.

For AES-GCM, the format is:

- nonce (IV) - 12 bytes
- ciphertext - variable length
- authentication tag - 16 bytes

Here are [some examples](docs/Compatibility.md).

For XSalsa20, use the appropriate [Libsodium library](https://libsodium.gitbook.io/doc/bindings_for_other_languages).

## Migrating from Another Library

Lockbox makes it easy to migrate from another library without downtime. The example below uses `attr_encrypted` but the same approach should work for any library.

Let’s suppose your model looks like this:

```ruby
class User < ApplicationRecord
  attr_encrypted :name, key: key
  attr_encrypted :email, key: key
end
```

Create a migration with:

```ruby
class MigrateToLockbox < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name_ciphertext, :text
    add_column :users, :email_ciphertext, :text
  end
end
```

And add `has_encrypted` to your model with the `migrating` option:

```ruby
class User < ApplicationRecord
  has_encrypted :name, :email, migrating: true
end
```

Then run:

```ruby
Lockbox.migrate(User)
```

Once all records are migrated, remove the `migrating` option and the previous model code (the `attr_encrypted` methods in this example).

```ruby
class User < ApplicationRecord
  has_encrypted :name, :email
end
```

Then remove the previous gem from your Gemfile and drop its columns.

```ruby
class RemovePreviousEncryptedColumns < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :encrypted_name, :text
    remove_column :users, :encrypted_name_iv, :text
    remove_column :users, :encrypted_email, :text
    remove_column :users, :encrypted_email_iv, :text
  end
end
```

## History

View the [changelog](https://github.com/ankane/lockbox/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/lockbox/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/lockbox/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development, [install Libsodium](https://github.com/crypto-rb/rbnacl/wiki/Installing-libsodium) and run:

```sh
git clone https://github.com/ankane/lockbox.git
cd lockbox
bundle install
bundle exec rake test
```

For security issues, send an email to the address on [this page](https://github.com/ankane).
